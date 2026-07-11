-- ============================================================
-- Vanguard Library | server/discord.lua
-- Comunicação com a API do Discord e cache de avatares.
-- ============================================================

DiscordAvatarCache = { Avatars = {} }

local discordBotAuth = "Bot " .. (Bot_Token or "")

--- Executa um request HTTP à API do Discord com autenticação de Bot.
--- @param method   string  Método HTTP ("GET", "POST", etc.)
--- @param endpoint string  Endpoint sem o domínio base
--- @param body     table   Corpo da request (será JSON-encodificado)
--- @return table | nil  { data, code, headers } ou nil em timeout
function performDiscordApiRequest(method, endpoint, body)
    local response = nil
    PerformHttpRequest(
        "https://discordapp.com/api/" .. endpoint,
        function(statusCode, responseData, responseHeaders)
            response = { data = responseData, code = statusCode, headers = responseHeaders }
        end,
        method,
        (#body > 0 and json.encode(body)) or "",
        { ["Content-Type"] = "application/json", Authorization = discordBotAuth }
    )
    local timeout = 50
    while response == nil and timeout > 0 do
        Citizen.Wait(100)
        timeout = timeout - 1
    end
    return response
end

DiscordRequest = performDiscordApiRequest

--- Obtém o URL do avatar Discord de um jogador, com cache.
--- @param playerId number  Server source ID
--- @return string | nil  URL do avatar (PNG ou GIF) ou nil
function getDiscordAvatarForPlayer(playerId)
    local discordId = nil
    for _, identifier in ipairs(GetPlayerIdentifiers(playerId)) do
        if string.match(identifier, "discord:") then
            discordId = string.gsub(identifier, "discord:", "")
            break
        end
    end
    if not discordId then return nil end

    if DiscordAvatarCache.Avatars[discordId] ~= nil then
        return DiscordAvatarCache.Avatars[discordId]
    end

    local apiResponse = DiscordRequest("GET", string.format("users/%s", discordId), {})
    local avatarUrl   = nil

    if apiResponse and apiResponse.code == 200 then
        local userData = json.decode(apiResponse.data)
        if userData and userData.avatar then
            local h = userData.avatar
            avatarUrl = "https://media.discordapp.net/avatars/"
                .. discordId .. "/" .. h
                .. (h:sub(1, 2) == "a_" and ".gif" or ".png")
        end
    end

    DiscordAvatarCache.Avatars[discordId] = avatarUrl
    return avatarUrl
end

GetDiscordAvatar = getDiscordAvatarForPlayer

exports('GetDiscordAvatar', function(playerId)
    return getDiscordAvatarForPlayer(playerId)
end)

exports('DiscordRequest', function(method, endpoint, body)
    return performDiscordApiRequest(method, endpoint, body)
end)

print("^5[Vanguard] Lib: discord loaded.^0")
