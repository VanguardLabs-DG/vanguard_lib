-- ============================================================
-- Vanguard Library | server/ratelimit.lua
-- Primitiva de rate limiting genérica para uso em qualquer resource.
-- ============================================================

local cooldowns = {}

RateLimiter = {}

--- Verifica se uma operação está dentro do limite de taxa.
--- Retorna true se permitido, false se ainda está em cooldown.
--- @param source number  Server ID do jogador
--- @param operation string  Identificador único da operação
--- @param cooldownMs number  Tempo mínimo entre operações em milissegundos
--- @return boolean true se permitido
function RateLimiter.Check(source, operation, cooldownMs)
    if not source or not operation or not cooldownMs then
        return false
    end
    local cooldown = tonumber(cooldownMs)
    if not cooldown or cooldown <= 0 then
        return true
    end
    local srcStr = tostring(source)
    local now = GetGameTimer()

    local playerCooldowns = cooldowns[srcStr]
    if playerCooldowns then
        local entry = playerCooldowns[operation]
        if entry and (now - entry.time) < cooldown then
            return false
        end
    else
        playerCooldowns = {}
        cooldowns[srcStr] = playerCooldowns
    end

    playerCooldowns[operation] = { time = now, expire = now + cooldown }
    return true
end

--- Remove todos os cooldowns de um jogador (útil no disconnect).
--- @param source number | string Server ID
function RateLimiter.Clear(source)
    if not source then return end
    cooldowns[tostring(source)] = nil
end

--- Remove todos os cooldowns (útil em resource restart).
function RateLimiter.ClearAll()
    cooldowns = {}
end

-- Limpeza periódica automática de cooldowns expirados para evitar vazamento de memória
CreateThread(function()
    while true do
        Wait(60000) -- Executa a cada 60 segundos
        local now = GetGameTimer()
        for srcStr, playerCooldowns in pairs(cooldowns) do
            local hasEntries = false
            for op, entry in pairs(playerCooldowns) do
                if entry and entry.expire and now >= entry.expire then
                    playerCooldowns[op] = nil
                else
                    hasEntries = true
                end
            end
            if not hasEntries then
                cooldowns[srcStr] = nil
            end
        end
    end
end)

-- Limpa cooldowns automaticamente ao desconectar
AddEventHandler('playerDropped', function()
    local src = source
    if src then
        RateLimiter.Clear(src)
    end
end)

exports('RateLimiterCheck', function(source, operation, cooldownMs)
    return RateLimiter.Check(source, operation, cooldownMs)
end)

exports('RateLimiterClear', function(source)
    RateLimiter.Clear(source)
end)

print("^5[Vanguard] Lib: ratelimit loaded.^0")

