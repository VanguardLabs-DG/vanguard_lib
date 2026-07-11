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
    local key = tostring(source) .. ":" .. operation
    local now = GetGameTimer()
    if cooldowns[key] and (now - cooldowns[key]) < cooldownMs then
        return false
    end
    cooldowns[key] = now
    return true
end

--- Remove todos os cooldowns de um jogador (útil no disconnect).
--- @param source number  Server ID
function RateLimiter.Clear(source)
    if not source then return end
    local prefix = tostring(source) .. ":"
    for key in pairs(cooldowns) do
        if key:sub(1, #prefix) == prefix then
            cooldowns[key] = nil
        end
    end
end

--- Remove todos os cooldowns (útil em resource restart).
function RateLimiter.ClearAll()
    cooldowns = {}
end

exports('RateLimiterCheck', function(source, operation, cooldownMs)
    return RateLimiter.Check(source, operation, cooldownMs)
end)

exports('RateLimiterClear', function(source)
    RateLimiter.Clear(source)
end)

print("^5[Vanguard] Lib: ratelimit loaded.^0")
