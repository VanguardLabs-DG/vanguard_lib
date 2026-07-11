-- ============================================================
-- Vanguard Library | client/geo.lua
-- Helpers geográficos e de proximidade.
-- ============================================================

--- Retorna uma lista com os server IDs dos jogadores próximos (raio 3.5u).
--- Usa ox_lib getNearbyPlayers para performance nativa.
--- @return table Lista de server IDs (números inteiros)
function GetClosestPlayers()
    local players = {}
    local nearby = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), 3.5)
    for _, player in ipairs(nearby) do
        table.insert(players, GetPlayerServerId(player.id))
    end
    return players
end

--- Retorna o nome da zona/bairro onde a posição fornecida se encontra.
--- @param position vector3
--- @return string Nome da zona (ex: "Vinewood Hills")
function findLastLocation(position)
    local var1, var2 = GetStreetNameAtCoord(position.x, position.y, position.z,
        Citizen.ResultAsInteger(), Citizen.ResultAsInteger())
    local zone      = GetNameOfZone(position.x, position.y, position.z)
    local zoneLabel = GetLabelText(zone)
    return zoneLabel
end

exports('GetClosestPlayers', function()
    return GetClosestPlayers()
end)

exports('FindLastLocation', function(position)
    return findLastLocation(position)
end)

print("^5[Vanguard] Lib: geo loaded.^0")
