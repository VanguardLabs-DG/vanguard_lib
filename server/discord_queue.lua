-- =========================================================================
-- VANGUARD LIBRARY v2.x | server/discord_queue.lua
-- Fila em Lote de Webhooks do Discord (Anti-Rate-Limit 429 & Embed Compactor)
-- Agrupa até 10 embeds por requisição HTTP, com prioridades e controle de cooldown.
-- =========================================================================

local DiscordQueue = {
    channels = {},
    queues = {}, -- [webhookUrl] = { items = {}, cooldownUntil = 0, droppedCount = 0 }
    isWorkerRunning = false,
    maxQueueSize = 1000,
    botUsername = "Vanguard Hub",
    avatarUrl = "https://i.imgur.com/83u6U0C.png"
}

-- Configurações padrão de canais via Convars ou aliases
local defaultChannels = {
    general    = GetConvar("vanguard_webhook_general", ""),
    admin      = GetConvar("vanguard_webhook_admin", ""),
    financeiro = GetConvar("vanguard_webhook_financeiro", ""),
    anticheat  = GetConvar("vanguard_webhook_anticheat", ""),
    inventario = GetConvar("vanguard_webhook_inventario", ""),
    veiculos   = GetConvar("vanguard_webhook_veiculos", "")
}

for k, v in pairs(defaultChannels) do
    if v and v ~= "" then
        DiscordQueue.channels[k] = v
    end
end

--- Valida se uma URL pertence estritamente aos domínios e caminhos oficiais do Discord (Anti-SSRF)
local function isValidDiscordWebhookUrl(url)
    if type(url) ~= "string" then return false end
    return url:match("^https://discord%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
        or url:match("^https://discordapp%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
        or url:match("^https://canary%.discord%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
        or url:match("^https://ptb%.discord%.com/api/webhooks/%d+/[%w%-_]+") ~= nil
end

--- Registra ou atualiza a URL de um canal nomeado
--- @param name string Nome do canal (ex: "financeiro", "anticheat")
--- @param webhookUrl string URL completa do Webhook
function DiscordQueue.setChannel(name, webhookUrl)
    if not name or not webhookUrl or webhookUrl == "" then return end
    if not isValidDiscordWebhookUrl(webhookUrl) then
        print(string.format("^1[Vanguard Discord Queue] URL inválida rejeitada para o canal '%s' (apenas webhooks oficiais do Discord são permitidos).^0", name))
        return
    end
    DiscordQueue.channels[name] = webhookUrl
end

--- Resolve a URL final do webhook a partir de canal ou URL direta
--- @param channelOrUrl string
--- @return string | nil
local function resolveWebhookUrl(channelOrUrl)
    if not channelOrUrl or channelOrUrl == "" then
        return DiscordQueue.channels.general ~= "" and DiscordQueue.channels.general or nil
    end

    if channelOrUrl:find("^https?://") then
        if isValidDiscordWebhookUrl(channelOrUrl) then
            return channelOrUrl
        end
        print(string.format("^1[Vanguard Discord Queue] URL rejeitada por falha na validação de domínio Discord: %s^0", channelOrUrl))
        return nil
    end

    if DiscordQueue.channels[channelOrUrl] and DiscordQueue.channels[channelOrUrl] ~= "" then
        return DiscordQueue.channels[channelOrUrl]
    end

    local convarVal = GetConvar("vanguard_webhook_" .. channelOrUrl, "")
    if convarVal and convarVal ~= "" and isValidDiscordWebhookUrl(convarVal) then
        DiscordQueue.channels[channelOrUrl] = convarVal
        return convarVal
    end

    return DiscordQueue.channels.general ~= "" and DiscordQueue.channels.general or nil
end

--- Obtém ou cria a estrutura de fila para uma URL de webhook
--- @param webhookUrl string
--- @return table
local function getQueue(webhookUrl)
    if not DiscordQueue.queues[webhookUrl] then
        DiscordQueue.queues[webhookUrl] = {
            items = {},
            cooldownUntil = 0,
            droppedCount = 0,
            lastDispatch = 0
        }
    end
    return DiscordQueue.queues[webhookUrl]
end

--- Inicia o worker assíncrono em loop somente quando houver mensagens pendentes
local function ensureWorkerRunning()
    if DiscordQueue.isWorkerRunning then return end
    DiscordQueue.isWorkerRunning = true

    Citizen.CreateThread(function()
        while true do
            local hasPendingItems = false
            local now = GetGameTimer()

            for webhookUrl, q in pairs(DiscordQueue.queues) do
                if #q.items > 0 then
                    hasPendingItems = true

                    -- Checa se o canal está em cooldown de 429
                    if now >= q.cooldownUntil then
                        local firstItem = q.items[1]
                        local waitTime = 2000 -- Padrão: 2 segundos de buffer

                        if firstItem.priority == "urgent" then
                            waitTime = 250 -- Alta prioridade despacha quase imediatamente
                        elseif firstItem.priority == "bulk" then
                            waitTime = 5000 -- Logs de baixo impacto acumulam mais
                        end

                        if (now - q.lastDispatch) >= waitTime then
                            -- Coleta até 10 embeds para compor 1 requisição HTTP
                            local batch = {}
                            local embeds = {}
                            local primaryContent = nil
                            local count = 0

                            while #q.items > 0 and count < 10 do
                                local item = table.remove(q.items, 1)
                                table.insert(batch, item)
                                count = count + 1

                                if item.content and not primaryContent then
                                    primaryContent = item.content
                                end

                                if item.embed then
                                    table.insert(embeds, item.embed)
                                end
                            end

                            -- Se houve descarte por saturação anterior, anexa aviso no primeiro embed
                            if q.droppedCount > 0 and #embeds > 0 then
                                embeds[1].fields = embeds[1].fields or {}
                                table.insert(embeds[1].fields, {
                                    name = "⚠️ Atenção de Fila",
                                    value = string.format("%d logs antigos foram descartados por sobrecarga da API do Discord.", q.droppedCount),
                                    inline = false
                                })
                                q.droppedCount = 0
                            end

                            local payload = {
                                username = DiscordQueue.botUsername,
                                avatar_url = DiscordQueue.avatarUrl,
                                content = primaryContent or "",
                                embeds = embeds,
                                allowed_mentions = { parse = {} }
                            }

                            q.lastDispatch = now

                            -- Envio HTTP assíncrono com leitura dos headers de Rate Limit
                            PerformHttpRequest(
                                webhookUrl,
                                function(statusCode, responseData, responseHeaders)
                                    if statusCode == 429 then
                                        -- Resposta 429: Too Many Requests!
                                        local retrySeconds = 3
                                        if responseData then
                                            local ok, decoded = pcall(json.decode, responseData)
                                            if ok and decoded and decoded.retry_after then
                                                retrySeconds = tonumber(decoded.retry_after) or 3
                                            end
                                        end

                                        local cooldownMs = math.ceil(retrySeconds * 1000) + 200
                                        q.cooldownUntil = GetGameTimer() + cooldownMs

                                        print(string.format(
                                            "^3[Vanguard Discord Queue] Webhook em Rate Limit (429)! Pausando fila por %.2f segundos.^0",
                                            retrySeconds
                                        ))

                                        -- Devolve os itens não enviados para a frente da fila
                                        for i = #batch, 1, -1 do
                                            table.insert(q.items, 1, batch[i])
                                        end
                                    elseif statusCode >= 400 then
                                        print(string.format(
                                            "^1[Vanguard Discord Queue] Erro HTTP %d ao despachar webhook: %s^0",
                                            statusCode, tostring(responseData)
                                        ))
                                    end
                                end,
                                "POST",
                                json.encode(payload),
                                { ["Content-Type"] = "application/json" }
                            )
                        end
                    end
                end
            end

            -- Se todas as filas estiverem vazias, hiberna o worker
            if not hasPendingItems then
                DiscordQueue.isWorkerRunning = false
                break
            end

            Citizen.Wait(200)
        end
    end)
end

--- Enfileira um log com agrupamento automático e proteção anti-429
--- @param options table { channel?: string, priority?: "urgent"|"normal"|"bulk", embed?: table, content?: string }
function DiscordQueue.log(options)
    if not options or type(options) ~= "table" then return false end

    local webhookUrl = resolveWebhookUrl(options.channel)
    if not webhookUrl then
        -- Se não houver webhook configurado, falha silenciosamente para não poluir console em dev
        return false
    end

    local q = getQueue(webhookUrl)

    -- Proteção contra estouro de memória (Ring Buffer seguro)
    if #q.items >= DiscordQueue.maxQueueSize then
        -- Remove o item mais antigo de prioridade baixa
        table.remove(q.items, 1)
        q.droppedCount = q.droppedCount + 1
    end

    table.insert(q.items, {
        priority = options.priority or "normal",
        embed = options.embed,
        content = options.content,
        timestamp = os.time()
    })

    ensureWorkerRunning()
    return true
end

--- Força o esvaziamento imediato da fila de um canal (útil em parada de recurso)
--- @param channelOrUrl? string
function DiscordQueue.flush(channelOrUrl)
    local now = GetGameTimer()
    for webhookUrl, q in pairs(DiscordQueue.queues) do
        if not channelOrUrl or resolveWebhookUrl(channelOrUrl) == webhookUrl then
            q.lastDispatch = 0
            q.cooldownUntil = 0
        end
    end
    ensureWorkerRunning()
end

-- =========================================================================
-- EXPORTS & INTEGRAÇÃO GLOBAL
-- =========================================================================

exports('DiscordLog', function(options)
    return DiscordQueue.log(options)
end)

exports('DiscordSetChannel', function(name, url)
    return DiscordQueue.setChannel(name, url)
end)

exports('DiscordFlush', function(channelOrUrl)
    return DiscordQueue.flush(channelOrUrl)
end)

VanguardDiscordQueue = DiscordQueue

print("^5[Vanguard] Lib: Discord Queue (Anti-429 & Batching) loaded.^0")
