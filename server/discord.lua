-- ============================================================
-- Vanguard Library | server/discord.lua
-- Comunicação com a API do Discord e cache de avatares.
-- ============================================================

DiscordAvatarCache = { Avatars = {} }

--- Executa um request HTTP à API do Discord com autenticação de Bot.
--- @param method   string  Método HTTP ("GET", "POST", etc.)
--- @param endpoint string  Endpoint sem o domínio base
--- @param body     table|string|nil  Corpo da request
--- @param cb       function|nil Callback opcional assíncrono: function(data, code, headers)
--- @return table | nil  { data, code, headers } ou nil em timeout
function performDiscordApiRequest(method, endpoint, body, cb)
    local token = Bot_Token or GetConvar("discord_bot_token", "")
    if not token or token == "" then
        print("^3[Vanguard Lib] discord_bot_token não configurado no server.cfg.^0")
        if cb and type(cb) == "function" then
            cb({ data = nil, code = 401, headers = {} })
            return
        end
        return { data = nil, code = 401, headers = {} }
    end

    -- Sanitiza e valida endpoint contra SSRF / Path Traversal / Host Injection
    local cleanEndpoint = tostring(endpoint or ""):gsub("^/+", "")
    if cleanEndpoint:find("@") or cleanEndpoint:find("%.%./") or cleanEndpoint:find("://") or cleanEndpoint:find("^[a-zA-Z]+:") then
        print(string.format("^1[Vanguard Security] Tentativa de SSRF/Injeção bloqueada no endpoint Discord: '%s'^0", tostring(endpoint)))
        if cb and type(cb) == "function" then
            cb({ data = nil, code = 400, headers = {} })
            return
        end
        return { data = nil, code = 400, headers = {} }
    end
    local url = "https://discord.com/api/v10/" .. cleanEndpoint
    local authHeader = "Bot " .. token
    local payload = ""

    if body and type(body) == "table" and next(body) ~= nil then
        payload = json.encode(body)
    elseif type(body) == "string" then
        payload = body
    end

    if cb and type(cb) == "function" then
        PerformHttpRequest(
            url,
            function(statusCode, responseData, responseHeaders)
                cb({ data = responseData, code = statusCode, headers = responseHeaders or {} })
            end,
            method or "GET",
            payload,
            { ["Content-Type"] = "application/json", Authorization = authHeader }
        )
        return
    end

    local p = promise.new()
    local isResolved = false

    SetTimeout(5000, function()
        if not isResolved then
            isResolved = true
            p:resolve({ data = nil, code = 408, headers = {} })
        end
    end)

    PerformHttpRequest(
        url,
        function(statusCode, responseData, responseHeaders)
            if not isResolved then
                isResolved = true
                p:resolve({ data = responseData, code = statusCode, headers = responseHeaders or {} })
            end
        end,
        method or "GET",
        payload,
        { ["Content-Type"] = "application/json", Authorization = authHeader }
    )

    return Citizen.Await(p)
end

DiscordRequest = performDiscordApiRequest

--- Obtém o URL do avatar Discord de um jogador, com cache.
--- @param playerId number  Server source ID
--- @return string | nil  URL do avatar (PNG ou GIF) ou nil
function getDiscordAvatarForPlayer(playerId)
    if not playerId or playerId == 0 then return nil end

    local identifiers = GetPlayerIdentifiers(playerId)
    if not identifiers then return nil end

    local discordId = nil
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, "discord:") then
            discordId = string.gsub(identifier, "discord:", "")
            break
        end
    end
    if not discordId or discordId == "" then return nil end

    local now = os.time()

    -- Limpeza periódica preventiva se o cache crescer muito
    if not DiscordAvatarCache.LastCleanup or (now - DiscordAvatarCache.LastCleanup) > 1800 then
        DiscordAvatarCache.LastCleanup = now
        for id, entry in pairs(DiscordAvatarCache.Avatars) do
            if entry and entry.expire and now >= entry.expire then
                DiscordAvatarCache.Avatars[id] = nil
            end
        end
    end

    local cached = DiscordAvatarCache.Avatars[discordId]
    if cached and cached.expire and now < cached.expire then
        return cached.url
    end

    local apiResponse = DiscordRequest("GET", string.format("users/%s", discordId), {})
    local avatarUrl = false -- Usa false para cache negativo temporário

    if apiResponse and apiResponse.code == 200 and apiResponse.data then
        local success, userData = pcall(json.decode, apiResponse.data)
        if success and type(userData) == "table" and userData.avatar then
            local h = userData.avatar
            avatarUrl = string.format("https://media.discordapp.net/avatars/%s/%s%s",
                discordId, h, (h:sub(1, 2) == "a_" and ".gif" or ".png"))
        end
    end

    -- TTL de 2 horas para avatares válidos e 15 minutos para cache negativo
    local ttl = (avatarUrl ~= false) and 7200 or 900
    DiscordAvatarCache.Avatars[discordId] = {
        url = (avatarUrl ~= false and avatarUrl or nil),
        expire = now + ttl
    }
    return avatarUrl ~= false and avatarUrl or nil
end

GetDiscordAvatar = getDiscordAvatarForPlayer

exports('GetDiscordAvatar', function(playerId)
    return getDiscordAvatarForPlayer(playerId)
end)

exports('DiscordRequest', function(method, endpoint, body, cb)
    return performDiscordApiRequest(method, endpoint, body, cb)
end)

print("^5[Vanguard] Lib: discord loaded.^0")
