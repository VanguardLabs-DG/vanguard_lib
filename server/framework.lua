-- ============================================================
-- Vanguard Library | server/framework.lua
-- Wrappers nativos do QBX Core.
-- Abstrai chamadas ao qbx_core para uso genérico.
-- ============================================================

--- Retorna o objeto Player do qbx_core para um dado source.
--- @param source number  Server source ID
--- @return table | nil
function GetPlayer(source)
    if not exports.qbx_core then return nil end
    return exports.qbx_core:GetPlayer(source)
end

--- Retorna o saldo (bank ou cash) de um jogador.
--- @param source number
--- @param value  string  "bank" | "cash"
--- @return number
function GetPlayerMoney(source, value)
    local player = GetPlayer(source)
    if player then
        return player.PlayerData.money[value] or 0
    end
    return 0
end

--- Remove dinheiro de um jogador.
--- @param source number
--- @param type   string  "bank" | "cash"
--- @param value  number
--- @return boolean
function RemoveMoney(source, type, value)
    local player = GetPlayer(source)
    if player then
        return player.Functions.RemoveMoney(type, value)
    end
    return false
end

--- Adiciona dinheiro a um jogador.
--- @param source number
--- @param type   string
--- @param value  number
--- @return boolean
function AddMoney(source, type, value)
    local player = GetPlayer(source)
    if player then
        return player.Functions.AddMoney(type, value)
    end
    return false
end

--- Retorna os dados de emprego do jogador.
--- @param source number
--- @return string, number, string, string  name, grade, joblabel, gradename
function GetJob(source)
    local player = GetPlayer(source)
    if player then
        local job = player.PlayerData.job
        return job.name, job.grade.level, job.label, job.grade.name
    end
    return false
end

--- Retorna o citizenid do jogador.
--- @param source number
--- @return string | nil
function GetIdentifier(source)
    local player = GetPlayer(source)
    return player and player.PlayerData.citizenid or nil
end

--- Retorna o nome completo do jogador.
--- @param source number
--- @return string
function GetName(source)
    local player = GetPlayer(tonumber(source))
    if player then
        return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    end
    return "Unknown Player"
end

function CheckIfAdmin(source)
    if not source or source == 0 then return false end
    return IsPlayerAceAllowed(source, 'command') or IsPlayerAceAllowed(source, 'group.admin')
end

--- Verifica se um jogador está em jogo (tem endpoint válido).
--- @param serverId number | string
--- @return boolean
function IsPlayerInGame(serverId)
    if serverId == nil or serverId == 0 then return false end
    local playerId = tonumber(serverId)
    if not playerId then return false end
    local endpoint = GetPlayerEndpoint(playerId)
    return endpoint ~= nil and endpoint ~= ""
end

exports('GetPlayer', function(source)
    return GetPlayer(source)
end)

exports('GetPlayerMoney', function(source, value)
    return GetPlayerMoney(source, value)
end)

exports('RemoveMoney', function(source, type, value)
    return RemoveMoney(source, type, value)
end)

exports('AddMoney', function(source, type, value)
    return AddMoney(source, type, value)
end)

exports('GetJob', function(source)
    return GetJob(source)
end)

exports('GetIdentifier', function(source)
    return GetIdentifier(source)
end)

exports('GetName', function(source)
    return GetName(source)
end)

exports('CheckIfAdmin', function(source)
    return CheckIfAdmin(source)
end)

exports('IsPlayerInGame', function(serverId)
    return IsPlayerInGame(serverId)
end)

print("^5[Vanguard] Lib: framework loaded.^0")
