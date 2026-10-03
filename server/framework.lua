-- ============================================================
-- Vanguard Library | server/framework.lua
-- Wrappers nativos do QBX Core.
-- Abstrai chamadas ao qbx_core para uso genérico.
-- ============================================================

--- Validador estrito de valores monetários
local function isValidAmount(value)
    return type(value) == "number"
        and value < 1e12
        and value == value -- Previne NaN
        and value ~= math.huge -- Previne Infinity
        and math.floor(value) > 0
end

--- Retorna o objeto Player do qbx_core para um dado source.
--- @param source number | string Server source ID
--- @return table | nil
function GetPlayer(source)
    if not exports.qbx_core or not source then return nil end
    local src = tonumber(source)
    if not src or src <= 0 then return nil end
    return exports.qbx_core:GetPlayer(src)
end

--- Retorna o saldo (bank, cash, gems, etc.) de um jogador por source ou citizenid.
--- @param target number | string Server ID ou CitizenID
--- @param value  string  "bank" | "cash" | "gems" | "crypto" | string
--- @return number
function GetPlayerMoney(target, value)
    local src = tonumber(target)
    if src and src > 0 then
        local player = GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.money then
            return player.PlayerData.money[value] or 0
        end
        if exports.qbx_core and exports.qbx_core.GetMoney then
            return exports.qbx_core:GetMoney(src, value) or 0
        end
    elseif type(target) == "string" and #target > 2 then
        if exports.qbx_core and exports.qbx_core.GetMoney then
            return exports.qbx_core:GetMoney(target, value) or 0
        end
    end
    return 0
end

--- Remove dinheiro/moeda de um jogador por source ou citizenid.
--- @param target number | string Server ID ou CitizenID
--- @param type   string  "bank" | "cash" | "gems" | "crypto" | string
--- @param value  number
--- @param reason? string  Motivo da transação para auditoria
--- @return boolean
function RemoveMoney(target, type, value, reason)
    if not isValidAmount(value) then return false end
    local src = tonumber(target)
    if src and src > 0 then
        local player = GetPlayer(src)
        if player and player.Functions and player.Functions.RemoveMoney then
            local ok = player.Functions.RemoveMoney(type, math.floor(value), reason or "vanguard_lib:RemoveMoney")
            if ok and type == 'gems' then
                pcall(function() Player(src).state:set('gems', player.PlayerData.money.gems, true) end)
            end
            return ok
        end
        if exports.qbx_core and exports.qbx_core.RemoveMoney then
            local ok = exports.qbx_core:RemoveMoney(src, type, math.floor(value), reason or "vanguard_lib:RemoveMoney")
            if ok and type == 'gems' then
                local current = exports.qbx_core:GetMoney(src, 'gems')
                pcall(function() Player(src).state:set('gems', current, true) end)
            end
            return ok
        end
    elseif type(target) == "string" and #target > 2 then
        if exports.qbx_core and exports.qbx_core.RemoveMoney then
            return exports.qbx_core:RemoveMoney(target, type, math.floor(value), reason or "vanguard_lib:RemoveMoney")
        end
    end
    return false
end

--- Adiciona dinheiro/moeda a um jogador por source ou citizenid.
--- @param target number | string Server ID ou CitizenID
--- @param type   string  "bank" | "cash" | "gems" | "crypto" | string
--- @param value  number
--- @param reason? string  Motivo da transação para auditoria
--- @return boolean
function AddMoney(target, type, value, reason)
    if not isValidAmount(value) then return false end
    local src = tonumber(target)
    if src and src > 0 then
        local player = GetPlayer(src)
        if player and player.Functions and player.Functions.AddMoney then
            local ok = player.Functions.AddMoney(type, math.floor(value), reason or "vanguard_lib:AddMoney")
            if ok and type == 'gems' then
                pcall(function() Player(src).state:set('gems', player.PlayerData.money.gems, true) end)
            end
            return ok
        end
        if exports.qbx_core and exports.qbx_core.AddMoney then
            local ok = exports.qbx_core:AddMoney(src, type, math.floor(value), reason or "vanguard_lib:AddMoney")
            if ok and type == 'gems' then
                local current = exports.qbx_core:GetMoney(src, 'gems')
                pcall(function() Player(src).state:set('gems', current, true) end)
            end
            return ok
        end
    elseif type(target) == "string" and #target > 2 then
        if exports.qbx_core and exports.qbx_core.AddMoney then
            return exports.qbx_core:AddMoney(target, type, math.floor(value), reason or "vanguard_lib:AddMoney")
        end
    end
    return false
end

--- Retorna o saldo de gemas VIP de um jogador.
--- @param target number | string Server ID ou CitizenID
--- @return number
function GetPlayerGems(target)
    return GetPlayerMoney(target, 'gems')
end

--- Adiciona gemas VIP a um jogador.
--- @param target number | string Server ID ou CitizenID
--- @param amount number
--- @param reason? string
--- @return boolean
function AddGems(target, amount, reason)
    return AddMoney(target, 'gems', amount, reason or "vanguard_lib:AddGems")
end

--- Remove gemas VIP de um jogador.
--- @param target number | string Server ID ou CitizenID
--- @param amount number
--- @param reason? string
--- @return boolean
function RemoveGems(target, amount, reason)
    return RemoveMoney(target, 'gems', amount, reason or "vanguard_lib:RemoveGems")
end

--- Retorna os dados de emprego do jogador.
--- @param source number | string
--- @return string, number, string, string  name, grade, joblabel, gradename
function GetJob(source)
    local player = GetPlayer(source)
    if player and player.PlayerData and player.PlayerData.job then
        local job = player.PlayerData.job
        return job.name, (job.grade and job.grade.level or 0), (job.label or ""), (job.grade and job.grade.name or "")
    end
    return false
end

--- Retorna o citizenid do jogador.
--- @param source number | string
--- @return string | nil
function GetIdentifier(source)
    local player = GetPlayer(source)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

--- Retorna o nome completo do jogador.
--- @param source number | string
--- @return string
function GetName(source)
    local player = GetPlayer(source)
    if player and player.PlayerData and player.PlayerData.charinfo then
        local info = player.PlayerData.charinfo
        return string.format("%s %s", info.firstname or "", info.lastname or ""):match("^%s*(.-)%s*$")
    end
    return "Unknown Player"
end

function CheckIfAdmin(source)
    local src = tonumber(source)
    if not src or src <= 0 then return false end

    -- 1. Checagem integrada ao QBX Core (HasPermission / HasGroup)
    if exports.qbx_core then
        local success, hasPerm = pcall(function()
            return exports.qbx_core:HasPermission(src, 'admin')
                or exports.qbx_core:HasGroup(src, 'admin')
                or exports.qbx_core:HasGroup(src, 'god')
        end)
        if success and hasPerm then
            return true
        end
    end

    -- 2. Fallback para ACE Permissions nativas do FiveM
    local srcStr = tostring(src)
    return IsPlayerAceAllowed(srcStr, 'group.admin')
        or IsPlayerAceAllowed(srcStr, 'command.admin')
        or IsPlayerAceAllowed(srcStr, 'command')
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

exports('RemoveMoney', function(source, type, value, reason)
    return RemoveMoney(source, type, value, reason)
end)

exports('AddMoney', function(source, type, value, reason)
    return AddMoney(source, type, value, reason)
end)

exports('GetPlayerGems', function(target)
    return GetPlayerGems(target)
end)

exports('AddGems', function(target, amount, reason)
    return AddGems(target, amount, reason)
end)

exports('RemoveGems', function(target, amount, reason)
    return RemoveGems(target, amount, reason)
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

local function isOxInventoryAvailable()
    return GetResourceState('ox_inventory') == 'started'
end

--- Adiciona item ao inventário do jogador (ox_inventory ou QBX Core)
--- @param source number | string Server ID
--- @param item string Nome do item
--- @param count? number Quantidade (padrão: 1)
--- @param metadata? table Metadados do item
--- @param slot? number Slot opcional
--- @return boolean
function AddItem(source, item, count, metadata, slot)
    local src = tonumber(source)
    if not src or src <= 0 or not item or item == "" then return false end
    count = count and math.floor(count) or 1
    if count <= 0 then return false end

    if isOxInventoryAvailable() then
        return exports.ox_inventory:AddItem(src, item, count, metadata, slot) and true or false
    end

    local player = GetPlayer(src)
    if player and player.Functions and player.Functions.AddItem then
        return player.Functions.AddItem(item, count, slot, metadata) and true or false
    end

    return false
end

--- Remove item do inventário do jogador (ox_inventory ou QBX Core)
--- @param source number | string Server ID
--- @param item string Nome do item
--- @param count? number Quantidade (padrão: 1)
--- @param metadata? table Metadados do item
--- @param slot? number Slot opcional
--- @return boolean
function RemoveItem(source, item, count, metadata, slot)
    local src = tonumber(source)
    if not src or src <= 0 or not item or item == "" then return false end
    count = count and math.floor(count) or 1
    if count <= 0 then return false end

    if isOxInventoryAvailable() then
        return exports.ox_inventory:RemoveItem(src, item, count, metadata, slot) and true or false
    end

    local player = GetPlayer(src)
    if player and player.Functions and player.Functions.RemoveItem then
        return player.Functions.RemoveItem(item, count, slot) and true or false
    end

    return false
end

--- Verifica se o jogador tem espaço/peso para carregar um item
--- @param source number | string
--- @param item string
--- @param count? number
--- @param metadata? table
--- @return boolean
function CanCarryItem(source, item, count, metadata)
    local src = tonumber(source)
    if not src or src <= 0 or not item or item == "" then return false end
    count = count and math.floor(count) or 1

    if isOxInventoryAvailable() then
        return exports.ox_inventory:CanCarryItem(src, item, count, metadata) and true or false
    end

    return true
end

--- Retorna a quantidade total de um item que o jogador possui
--- @param source number | string
--- @param item string
--- @param metadata? table
--- @return number
function GetItemCount(source, item, metadata)
    local src = tonumber(source)
    if not src or src <= 0 or not item or item == "" then return 0 end

    if isOxInventoryAvailable() then
        return exports.ox_inventory:GetItemCount(src, item, metadata, false) or 0
    end

    local player = GetPlayer(src)
    if player and player.Functions and player.Functions.GetItemByName then
        local itemData = player.Functions.GetItemByName(item)
        return itemData and (itemData.amount or itemData.count or 0) or 0
    end

    return 0
end

exports('AddItem', function(source, item, count, metadata, slot)
    return AddItem(source, item, count, metadata, slot)
end)

exports('RemoveItem', function(source, item, count, metadata, slot)
    return RemoveItem(source, item, count, metadata, slot)
end)

exports('CanCarryItem', function(source, item, count, metadata)
    return CanCarryItem(source, item, count, metadata)
end)

exports('GetItemCount', function(source, item, metadata)
    return GetItemCount(source, item, metadata)
end)

print("^5[Vanguard] Lib: framework loaded.^0")

