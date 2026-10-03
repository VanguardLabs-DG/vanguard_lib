-- =========================================================================
-- VANGUARD LIBRARY v2.0 | init.lua
-- Core Framework & Modular API for Vanguard Ecosystem Resources
-- Compatible with Lua 5.4, QBX Core, and ox_lib
-- =========================================================================

local isServer = IsDuplicityVersion()
local currentResource = GetCurrentResourceName()

vanguard = vanguard or {}
vanguard.isServer = isServer
vanguard.version = "2.5.0"
vanguard.libResource = "vanguard_lib"

-- =========================================================================
-- 1. RATE LIMITER (Server & Client Gateway)
-- =========================================================================
--- Checa se uma operação está dentro da taxa permitida de execução.
--- @param source number Server ID do jogador (ou 0 para chamadas locais de cliente)
--- @param operation string Identificador único da ação (ex: "comprar_item")
--- @param cooldownMs number Cooldown mínimo em milissegundos
--- @return boolean true se permitido, false se bloqueado em cooldown
function vanguard.rateLimit(source, operation, cooldownMs)
    if isServer and RateLimiter and RateLimiter.Check then
        return RateLimiter.Check(source, operation, cooldownMs)
    end
    if GetResourceState(vanguard.libResource) ~= "started" then
        return true -- Fail-open seguro: se a lib estiver parando/reiniciando, não bloqueia o jogador
    end
    local ok, res = pcall(function()
        if isServer then
            return exports[vanguard.libResource]:RateLimiterCheck(source, operation, cooldownMs)
        end
        return exports[vanguard.libResource]:RateLimiterCheck(GetPlayerServerId(PlayerId()), operation, cooldownMs)
    end)
    return ok and res or true
end

--- Limpa os cooldowns de um jogador (útil em desconexão ou reset)
--- @param source number
function vanguard.clearRateLimit(source)
    if isServer then
        if RateLimiter and RateLimiter.Clear then
            RateLimiter.Clear(source)
            return
        end
        if GetResourceState(vanguard.libResource) == "started" then
            pcall(function()
                exports[vanguard.libResource]:RateLimiterClear(source)
            end)
        end
    end
end

-- =========================================================================
-- 2. CALLBACKS (Seguros e Tipados sobre ox_lib)
-- =========================================================================
vanguard.callback = {}

if isServer then
    --- Registra um callback no servidor para responder requisições do cliente.
    --- @param name string Nome do callback
    --- @param cb function Função callback (source, cbRef, ...)
    function vanguard.callback.register(name, cb)
        if lib and lib.callback then
            return lib.callback.register(name, cb)
        end
        error("^1[Vanguard Lib] ox_lib necessária para registrar callbacks de servidor.^0")
    end
else
    --- Dispara um callback no servidor e aguarda a resposta (síncrono/await).
    --- @param name string Nome do callback
    --- @param ... any Argumentos adicionais
    --- @return any
    function vanguard.callback.await(name, ...)
        if lib and lib.callback then
            return lib.callback.await(name, false, ...)
        end
        return TriggerServerCallback(name, ...)
    end
end

-- =========================================================================
-- 3. MIDDLEWARE DE EVENTOS DE REDE (Server-Side Declarativo)
-- =========================================================================
if isServer then
    --- Registra um NetEvent com proteções integradas de Rate-Limit, Autenticação, Tipagem e Anti-Executor.
    --- @param eventName string Nome do evento
    --- @param options table|function Configuração das proteções ou handler direto
    --- @param handler? function Função executora (source, ...)
    function vanguard.registerServerEvent(eventName, options, handler)
        if type(options) == "function" then
            handler = options
            options = {}
        end
        options = options or {}

        RegisterNetEvent(eventName, function(...)
            local src = source
            local args = table.pack(...)

            -- 1. Anti-Spoof: Valida se o endpoint do jogador é real e válido
            if options.requireAuth ~= false then
                local endpoint = GetPlayerEndpoint(src)
                if not endpoint or endpoint == "" then
                    return
                end
            end

            -- 2. Anti-Executor: Validação de One-Time Token se requireToken = true
            if options.requireToken then
                local token = args[1]
                local isValid = false

                if VanguardSecurity and VanguardSecurity.validateToken then
                    isValid = VanguardSecurity.validateToken(src, eventName, token)
                elseif GetResourceState(vanguard.libResource) == "started" then
                    local ok, res = pcall(function()
                        return exports[vanguard.libResource]:ValidateSecurityToken(src, eventName, token)
                    end)
                    isValid = ok and res
                end

                if not isValid then
                    print(string.format(
                        "^1[Vanguard Security] Injeção de evento bloqueada em '%s' de [%s]! Token One-Time ausente ou inválido.^0",
                        eventName, tostring(src)
                    ))

                    if vanguard.discord and vanguard.discord.log then
                        vanguard.discord.log({
                            channel = "anticheat",
                            priority = "urgent",
                            embed = {
                                title = "🛡️ Bloqueio de Injeção de Evento (Anti-Executor)",
                                description = string.format("Tentativa de disparar NetEvent sensível sem token NUI válido."),
                                color = 0xef4444,
                                fields = {
                                    { name = "Jogador (Source)", value = tostring(src), inline = true },
                                    { name = "Evento Alvo", value = eventName, inline = true },
                                    { name = "Token Recebido", value = tostring(token or "NIL"), inline = false }
                                }
                            }
                        })
                    end

                    if options.onSecurityViolation then
                        options.onSecurityViolation(src, eventName, token)
                    end
                    return
                end

                -- Remove o token descartável consumido dos argumentos
                table.remove(args, 1)
                args.n = args.n - 1
            end

            -- 3. Anti-Macro / Anti-Race-Condition: Rate limiting automático
            if options.rateLimit and options.rateLimit > 0 then
                local allowed = exports[vanguard.libResource]:RateLimiterCheck(src, eventName, options.rateLimit)
                if not allowed then
                    if options.onRateLimited then
                        options.onRateLimited(src, eventName)
                    end
                    return
                end
            end

            -- 3. Type Safety: Validação estrita de tipos dos argumentos recebidos (suporta opcionais com "?")
            if options.validateArgs and type(options.validateArgs) == "table" then
                for i, expectedType in ipairs(options.validateArgs) do
                    local val = args[i]
                    local actualType = type(val)
                    local isOptional = expectedType:sub(1, 1) == "?"
                    local targetType = isOptional and expectedType:sub(2) or expectedType

                    if targetType ~= "any" then
                        if not (isOptional and actualType == "nil") and actualType ~= targetType then
                            print(string.format(
                                "^1[Vanguard Security] Tipo inválido no evento '%s' de [%s] no param #%d: esperado '%s', recebido '%s'. Ação descartada.^0",
                                eventName, tostring(src), i, expectedType, actualType
                            ))
                            if options.onValidationFailed then
                                options.onValidationFailed(src, i, expectedType, actualType)
                            end
                            return
                        end
                    end
                end
            end

            -- 4. Execução Segura: Captura erros de runtime sem travar a thread global (preserva limites exatos de argumentos)
            local success, err = pcall(handler, src, table.unpack(args, 1, args.n))
            if not success then
                print(string.format(
                    "^1[Vanguard Event Error] Erro ao executar '%s' para [%s]: %s^0",
                    eventName, tostring(src), tostring(err)
                ))
            end
        end)
    end
end

-- =========================================================================
-- 4. PLAYER & ECONOMY APIS (Server-Side)
-- =========================================================================
if isServer then
    vanguard.player = {}

    --- Retorna o objeto Player do QBX Core
    --- @param source number | string
    --- @return table | nil
    function vanguard.player.get(source)
        return exports[vanguard.libResource]:GetPlayer(source)
    end

    --- Retorna o saldo bancário ou em dinheiro do jogador
    --- @param source number | string
    --- @param moneyType string "bank" | "cash"
    --- @return number
    function vanguard.player.getMoney(source, moneyType)
        return exports[vanguard.libResource]:GetPlayerMoney(source, moneyType)
    end

    --- Adiciona dinheiro ao jogador com registro de auditoria
    --- @param source number | string
    --- @param moneyType string "bank" | "cash"
    --- @param amount number Valor positivo
    --- @param reason? string Motivo para log e auditoria
    --- @return boolean
    function vanguard.player.addMoney(source, moneyType, amount, reason)
        return exports[vanguard.libResource]:AddMoney(source, moneyType, amount, reason or (currentResource .. ":addMoney"))
    end

    --- Remove dinheiro do jogador com registro de auditoria
    --- @param source number | string
    --- @param moneyType string "bank" | "cash"
    --- @param amount number Valor positivo
    --- @param reason? string Motivo para log e auditoria
    --- @return boolean
    function vanguard.player.removeMoney(source, moneyType, amount, reason)
        return exports[vanguard.libResource]:RemoveMoney(source, moneyType, amount, reason or (currentResource .. ":removeMoney"))
    end

    --- Retorna informações de emprego do jogador
    --- @param source number | string
    --- @return string, number, string, string name, grade, label, gradename
    function vanguard.player.getJob(source)
        return exports[vanguard.libResource]:GetJob(source)
    end

    --- Retorna o CitizenID do jogador
    --- @param source number | string
    --- @return string | nil
    function vanguard.player.getCitizenId(source)
        return exports[vanguard.libResource]:GetIdentifier(source)
    end

    --- Retorna o nome formatado do personagem
    --- @param source number | string
    --- @return string
    function vanguard.player.getName(source)
        return exports[vanguard.libResource]:GetName(source)
    end

    --- Verifica se o jogador possui permissão de administrador
    --- @param source number | string
    --- @return boolean
    function vanguard.player.isAdmin(source)
        return exports[vanguard.libResource]:CheckIfAdmin(source)
    end

    --- Verifica se o jogador está conectado com endpoint válido
    --- @param source number | string
    --- @return boolean
    function vanguard.player.isOnline(source)
        return exports[vanguard.libResource]:IsPlayerInGame(source)
    end

    --- Retorna identificadores Steam, Discord e License
    --- @param source number | string
    --- @return table { steam, discord, license }
    function vanguard.player.getIdentifiers(source)
        return exports[vanguard.libResource]:ExtractIdentifiers(source)
    end
end

-- =========================================================================
-- 5. GEOMETRIA & PROXIMIDADE (Client-Side)
-- =========================================================================
if not isServer then
    vanguard.geo = {}

    --- Retorna a lista de Server IDs dos jogadores próximos (raio padrão 3.5u)
    --- @return table
    function vanguard.geo.getClosestPlayers()
        return exports[vanguard.libResource]:GetClosestPlayers()
    end

    --- Retorna o nome do bairro/zona de uma coordenada
    --- @param position vector3
    --- @return string
    function vanguard.geo.getStreetZone(position)
        return exports[vanguard.libResource]:FindLastLocation(position)
    end
end

-- =========================================================================
-- 6. UTILITÁRIOS GERAIS
-- =========================================================================
--- Gera um UUID v4 compatível com RFC 4122
--- @return string
function vanguard.uuid()
    if isServer then
        return exports[vanguard.libResource]:GenerateId()
    end
    -- Fallback local se chamado no cliente
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

-- Utilitários Discord (Server-Side)
if isServer then
    vanguard.discord = {}

    --- Retorna a URL do avatar Discord do jogador (em cache)
    --- @param source number
    --- @return string | nil
    function vanguard.discord.getAvatar(source)
        return exports[vanguard.libResource]:GetDiscordAvatar(source)
    end

    --- Executa uma requisição autenticada à API do Discord
    --- @param method string "GET" | "POST" | "PATCH"
    --- @param endpoint string Endpoint da API v10
    --- @param body table | string | nil
    --- @param cb? function
    --- @return table | nil
    function vanguard.discord.request(method, endpoint, body, cb)
        return exports[vanguard.libResource]:DiscordRequest(method, endpoint, body, cb)
    end

    --- Enfileira um log com agrupamento de até 10 embeds e proteção anti-429
    --- @param options table { channel?: string, priority?: "urgent"|"normal"|"bulk", embed?: table, content?: string }
    --- @return boolean
    function vanguard.discord.log(options)
        if VanguardDiscordQueue and VanguardDiscordQueue.log then
            return VanguardDiscordQueue.log(options)
        end
        if exports[vanguard.libResource] and exports[vanguard.libResource].DiscordLog then
            return exports[vanguard.libResource]:DiscordLog(options)
        end
        return false
    end

    --- Configura a URL de um canal de webhook
    --- @param name string Nome do canal (ex: "financeiro", "anticheat")
    --- @param webhookUrl string URL completa do webhook
    function vanguard.discord.setChannel(name, webhookUrl)
        if VanguardDiscordQueue and VanguardDiscordQueue.setChannel then
            return VanguardDiscordQueue.setChannel(name, webhookUrl)
        end
        if exports[vanguard.libResource] and exports[vanguard.libResource].DiscordSetChannel then
            return exports[vanguard.libResource]:DiscordSetChannel(name, webhookUrl)
        end
    end

    --- Força o esvaziamento imediato da fila
    --- @param channelOrUrl? string
    function vanguard.discord.flush(channelOrUrl)
        if VanguardDiscordQueue and VanguardDiscordQueue.flush then
            return VanguardDiscordQueue.flush(channelOrUrl)
        end
        if exports[vanguard.libResource] and exports[vanguard.libResource].DiscordFlush then
            return exports[vanguard.libResource]:DiscordFlush(channelOrUrl)
        end
    end
end

-- =========================================================================
-- 7. GERENCIADOR DE TRANSAÇÕES ATÔMICAS (ACID FiveM / Sagas com Rollback)
-- =========================================================================
if isServer then
    vanguard.transaction = {}

    --- Executa um bloco transacional com compensação reversa LIFO em caso de falha.
    --- @param options table | function { source?, label?, timeout?, lock?, lockKey?, onRollback?, onCommit? }
    --- @param handler? function function(tx) -> result
    --- @return boolean success, any result, table | nil errInfo
    function vanguard.transaction.run(options, handler)
        if VanguardTransaction and VanguardTransaction.run then
            return VanguardTransaction.run(options, handler)
        end
        return exports[vanguard.libResource]:TransactionRun(options, handler)
    end

    --- Adquire uma trava exclusiva de concorrência
    --- @param lockKey string
    --- @param holder any
    --- @param timeoutMs? number
    --- @return boolean
    function vanguard.transaction.lock(lockKey, holder, timeoutMs)
        if VanguardTransaction and VanguardTransaction.acquireLock then
            return VanguardTransaction.acquireLock(lockKey, holder, timeoutMs)
        end
        return exports[vanguard.libResource]:TransactionAcquireLock(lockKey, holder, timeoutMs)
    end

    --- Libera uma trava exclusiva de concorrência
    --- @param lockKey string
    --- @param holder? any
    function vanguard.transaction.unlock(lockKey, holder)
        if VanguardTransaction and VanguardTransaction.releaseLock then
            return VanguardTransaction.releaseLock(lockKey, holder)
        end
        return exports[vanguard.libResource]:TransactionReleaseLock(lockKey, holder)
    end
end

-- =========================================================================
-- 8. INVENTÁRIO PADRONIZADO (ox_inventory / QBX Core)
-- =========================================================================
if isServer then
    vanguard.inventory = {}

    --- Adiciona item ao inventário do jogador com validações
    --- @param source number | string
    --- @param item string
    --- @param count? number
    --- @param metadata? table
    --- @param slot? number
    --- @return boolean
    function vanguard.inventory.addItem(source, item, count, metadata, slot)
        if AddItem then
            return AddItem(source, item, count, metadata, slot)
        end
        return exports[vanguard.libResource]:AddItem(source, item, count, metadata, slot)
    end

    --- Remove item do inventário do jogador
    --- @param source number | string
    --- @param item string
    --- @param count? number
    --- @param metadata? table
    --- @param slot? number
    --- @return boolean
    function vanguard.inventory.removeItem(source, item, count, metadata, slot)
        if RemoveItem then
            return RemoveItem(source, item, count, metadata, slot)
        end
        return exports[vanguard.libResource]:RemoveItem(source, item, count, metadata, slot)
    end

    --- Checa se o jogador pode carregar o item (peso / slots)
    --- @param source number | string
    --- @param item string
    --- @param count? number
    --- @param metadata? table
    --- @return boolean
    function vanguard.inventory.canCarryItem(source, item, count, metadata)
        if CanCarryItem then
            return CanCarryItem(source, item, count, metadata)
        end
        return exports[vanguard.libResource]:CanCarryItem(source, item, count, metadata)
    end

    --- Retorna a quantidade de um item no inventário
    --- @param source number | string
    --- @param item string
    --- @param metadata? table
    --- @return number
    function vanguard.inventory.getItemCount(source, item, metadata)
        if GetItemCount then
            return GetItemCount(source, item, metadata)
        end
        return exports[vanguard.libResource]:GetItemCount(source, item, metadata)
    end
end

-- =========================================================================
-- 9. STATE STORE GLOBAL & REATIVIDADE (Server & Client)
-- =========================================================================
vanguard.state = {}

if isServer then
    --- Define uma chave de estado no servidor e transmite para o cliente/NUI
    --- @param source number | string Server ID (ou 0 / -1 para Global)
    --- @param key string
    --- @param value any
    function vanguard.state.set(source, key, value)
        if VanguardState and VanguardState.set then
            return VanguardState.set(source, key, value)
        end
        return exports[vanguard.libResource]:StateSet(source, key, value)
    end

    --- Obtém o valor de uma chave de estado
    --- @param source number | string
    --- @param key string
    --- @param defaultValue? any
    --- @return any
    function vanguard.state.get(source, key, defaultValue)
        if VanguardState and VanguardState.get then
            return VanguardState.get(source, key, defaultValue)
        end
        return exports[vanguard.libResource]:StateGet(source, key, defaultValue)
    end

    --- Atualiza múltiplas chaves de estado de uma vez (Patch)
    --- @param source number | string
    --- @param patchTable table
    function vanguard.state.patch(source, patchTable)
        if VanguardState and VanguardState.patch then
            return VanguardState.patch(source, patchTable)
        end
        return exports[vanguard.libResource]:StatePatch(source, patchTable)
    end

    --- Retorna o snapshot completo do estado
    --- @param source number | string
    --- @return table
    function vanguard.state.getSnapshot(source)
        if VanguardState and VanguardState.getSnapshot then
            return VanguardState.getSnapshot(source)
        end
        return exports[vanguard.libResource]:StateGetSnapshot(source)
    end
else
    --- Obtém o valor de uma chave no estado local do cliente
    --- @param key string
    --- @param defaultValue? any
    --- @return any
    function vanguard.state.get(key, defaultValue)
        if VanguardClientState and VanguardClientState.get then
            return VanguardClientState.get(key, defaultValue)
        end
        return exports[vanguard.libResource]:StateGet(key, defaultValue)
    end

    --- Define o valor no estado local e transmite para a NUI
    --- @param key string
    --- @param value any
    function vanguard.state.set(key, value)
        if VanguardClientState and VanguardClientState.set then
            return VanguardClientState.set(key, value)
        end
        return exports[vanguard.libResource]:StateSet(key, value)
    end

    --- Atualiza múltiplas chaves de uma vez
    --- @param patchTable table
    function vanguard.state.patch(patchTable)
        if VanguardClientState and VanguardClientState.patch then
            return VanguardClientState.patch(patchTable)
        end
        return exports[vanguard.libResource]:StatePatch(patchTable)
    end

    --- Retorna o snapshot local do cliente
    --- @return table
    function vanguard.state.getSnapshot()
        if VanguardClientState and VanguardClientState.getSnapshot then
            return VanguardClientState.getSnapshot()
        end
        return exports[vanguard.libResource]:StateGetSnapshot()
    end
end

-- =========================================================================
-- 10. SEGURANÇA CRIPTOGRÁFICA & HANDSHAKE (Anti-Executor)
-- =========================================================================
vanguard.security = {}

if isServer then
    --- Emite um token de uso único (Nonce) para uma ação sensível
    --- @param source number | string
    --- @param actionName string
    --- @param ttlMs? number
    --- @return string | nil
    function vanguard.security.issueToken(source, actionName, ttlMs)
        if VanguardSecurity and VanguardSecurity.issueToken then
            return VanguardSecurity.issueToken(source, actionName, ttlMs)
        end
        return exports[vanguard.libResource]:IssueSecurityToken(source, actionName, ttlMs)
    end

    --- Valida e consome imediatamente um token de segurança
    --- @param source number | string
    --- @param actionName string
    --- @param token string
    --- @return boolean
    function vanguard.security.validateToken(source, actionName, token)
        if VanguardSecurity and VanguardSecurity.validateToken then
            return VanguardSecurity.validateToken(source, actionName, token)
        end
        return exports[vanguard.libResource]:ValidateSecurityToken(source, actionName, token)
    end
else
    --- Solicita um token descartável ao servidor para uma ação sensível
    --- @param actionName string
    --- @return string | nil
    function vanguard.security.requestToken(actionName)
        if VanguardClientSecurity and VanguardClientSecurity.requestToken then
            return VanguardClientSecurity.requestToken(actionName)
        end
        return exports[vanguard.libResource]:RequestSecurityToken(actionName)
    end

    --- Dispara um NetEvent assinado automaticamente com token de uso único
    --- @param eventName string
    --- @param ... any
    --- @return boolean
    function vanguard.security.triggerSecuredServerEvent(eventName, ...)
        if VanguardClientSecurity and VanguardClientSecurity.triggerSecuredServerEvent then
            return VanguardClientSecurity.triggerSecuredServerEvent(eventName, ...)
        end
        return exports[vanguard.libResource]:TriggerSecuredServerEvent(eventName, ...)
    end
end

-- =========================================================================
-- 11. ONESYNC ENGINE GUARD & CRASH SHIELD (v2.5.0)
-- =========================================================================
if isServer then
    vanguard.guard = {}

    --- Verifica se o jogador possui imunidade administrativa no Guard
    --- @param source number | string
    --- @return boolean
    function vanguard.guard.isStaff(source)
        if exports[vanguard.libResource] and exports[vanguard.libResource].GuardIsStaff then
            return exports[vanguard.libResource]:GuardIsStaff(tonumber(source))
        end
        return false
    end

    --- Recarrega as blacklists de modelos, projéteis e explosões em tempo de execução
    --- @return boolean
    function vanguard.guard.refreshBlacklists()
        if exports[vanguard.libResource] and exports[vanguard.libResource].GuardRefreshBlacklists then
            return exports[vanguard.libResource]:GuardRefreshBlacklists()
        end
        return false
    end

    --- Checa se uma tabela de StateBag é segura contra DoS/Nesting Bombs
    --- @param tbl table
    --- @param maxDepth? number
    --- @param maxKeys? number
    --- @return boolean
    function vanguard.guard.isTableSafe(tbl, maxDepth, maxKeys)
        if exports[vanguard.libResource] and exports[vanguard.libResource].GuardIsTableSafe then
            return exports[vanguard.libResource]:GuardIsTableSafe(tbl, maxDepth, maxKeys)
        end
        return true
    end

    --- Checa se o veículo está acoplado a reboque, guincho ou trailer
    --- @param entity number
    --- @return boolean
    function vanguard.guard.isVehicleAttached(entity)
        if exports[vanguard.libResource] and exports[vanguard.libResource].GuardIsVehicleAttached then
            return exports[vanguard.libResource]:GuardIsVehicleAttached(entity)
        end
        return false
    end
end




