-- ============================================================
-- Vanguard Library | server/helpers.lua
-- Funções utilitárias genéricas: geração de IDs e identificadores.
-- ============================================================

-- Inicializa a semente do PRNG com entropia de tempo e clock do sistema
math.randomseed(os.time() ~ math.floor(os.clock() * 1000000))

--- Gera um UUID v4 aleatório compatível com a especificação RFC 4122.
--- @return string UUID no formato "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
function GenerateId()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

--- Extrai os identificadores Steam, Discord e License de um jogador.
--- @param src number | string  Server source ID
--- @return table { steam, discord, license }
function ExtractIdentifiers(src)
    local identifiers = { steam = "", discord = "", license = "" }
    local playerId = tonumber(src)
    if not playerId or playerId <= 0 then return identifiers end

    local numIdentifiers = GetNumPlayerIdentifiers(playerId)
    if not numIdentifiers or numIdentifiers <= 0 then return identifiers end

    for i = 0, numIdentifiers - 1 do
        local id = GetPlayerIdentifier(playerId, i)
        if id then
            if string.find(id, "steam:") then
                identifiers.steam = id
            elseif string.find(id, "discord:") then
                identifiers.discord = "<@" .. id:gsub("discord:", "") .. ">"
            elseif string.find(id, "license:") then
                identifiers.license = id
            end
        end
    end
    return identifiers
end

exports('GenerateId', function()
    return GenerateId()
end)

exports('ExtractIdentifiers', function(src)
    return ExtractIdentifiers(src)
end)

print("^5[Vanguard] Lib: helpers loaded.^0")
