-- ============================================================
-- Vanguard Library | server/helpers.lua
-- Funções utilitárias genéricas: geração de IDs e identificadores.
-- ============================================================

--- Gera um UUID v4 aleatório.
--- @return string UUID no formato "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
function GenerateId()
    local random    = math.random
    local templates = {
        'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx',
        'xxxxxxxx-2xxx-xxxx-yxxx-xxxxxxxxxxxx',
        'xxxxxxxx-xxxx-8xxx-yxxx-xxxxxxxxxxxx',
        'xxxxxxxx-1xxx-xxxx-yxxx-xxxxxxxxxxxx',
        'xxxxxxxx-6xxx-xxxx-yxxx-xxxxxxxxxxxx',
    }
    local template = templates[random(1, #templates)]
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

--- Extrai os identificadores Steam, Discord e License de um jogador.
--- @param src number  Server source ID
--- @return table { steam, discord, license }
function ExtractIdentifiers(src)
    local identifiers = { steam = "", discord = "", license = "" }
    if src == nil or src == 0 then return identifiers end
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if string.find(id, "steam") then
            identifiers.steam = id
        elseif string.find(id, "discord") then
            identifiers.discord = "<@" .. id:gsub("discord:", "") .. ">"
        elseif string.find(id, "license") then
            identifiers.license = id
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
