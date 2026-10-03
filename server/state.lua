-- =========================================================================
-- VANGUARD LIBRARY v2.x | server/state.lua
-- Gerenciador de Estado Global e Reatividade Server -> Client -> NUI
-- Sincroniza dados do jogador (gemas, saldo, VIP) entre Server, Client e Microfrontends.
-- =========================================================================

local PlayerStates = {} -- [source] = { [key] = value }
local GlobalState = {}  -- [key] = value

local StateManager = {}

--- Define uma chave de estado para um jogador específico ou global
--- @param source number | string Server ID (ou -1 / 0 para Global)
--- @param key string Caminho da chave (suporta dot notation como "vip.tier")
--- @param value any Valor da chave
function StateManager.set(source, key, value)
    local src = tonumber(source)
    if not key or key == "" then return end

    if not src or src <= 0 then
        -- Estado Global
        GlobalState[key] = value
        TriggerClientEvent("vanguard:state:sync", -1, { [key] = value })
        return
    end

    if not PlayerStates[src] then
        PlayerStates[src] = {}
    end

    PlayerStates[src][key] = value

    -- Envia atualização em tempo real para o cliente
    TriggerClientEvent("vanguard:state:sync", src, { [key] = value })
end

--- Retorna o valor de uma chave de estado
--- @param source number | string Server ID (ou 0 / -1 para Global)
--- @param key string
--- @param defaultValue? any
--- @return any
function StateManager.get(source, key, defaultValue)
    local src = tonumber(source)
    if not src or src <= 0 then
        local val = GlobalState[key]
        return val ~= nil and val or defaultValue
    end

    if not PlayerStates[src] then
        return defaultValue
    end

    local val = PlayerStates[src][key]
    return val ~= nil and val or defaultValue
end

--- Atualiza múltiplas chaves de estado de uma vez (Patch)
--- @param source number | string Server ID (ou 0 / -1 para Global)
--- @param patchTable table
function StateManager.patch(source, patchTable)
    if not patchTable or type(patchTable) ~= "table" then return end
    local src = tonumber(source)

    if not src or src <= 0 then
        for k, v in pairs(patchTable) do
            GlobalState[k] = v
        end
        TriggerClientEvent("vanguard:state:sync", -1, patchTable)
        return
    end

    if not PlayerStates[src] then
        PlayerStates[src] = {}
    end

    for k, v in pairs(patchTable) do
        PlayerStates[src][k] = v
    end

    TriggerClientEvent("vanguard:state:sync", src, patchTable)
end

--- Retorna o snapshot completo do estado de um jogador
--- @param source number | string
--- @return table
function StateManager.getSnapshot(source)
    local src = tonumber(source)
    local snapshot = {}

    -- Combina estado global
    for k, v in pairs(GlobalState) do
        snapshot[k] = v
    end

    -- Mescla estado individual do player
    if src and src > 0 and PlayerStates[src] then
        for k, v in pairs(PlayerStates[src]) do
            snapshot[k] = v
        end
    end

    return snapshot
end

-- Limpeza de memória preventiva na desconexão (trata coerção string/number)
AddEventHandler("playerDropped", function()
    local src = source
    local numSrc = tonumber(src)
    PlayerStates[src] = nil
    if numSrc then
        PlayerStates[numSrc] = nil
    end
end)

-- Permite que o cliente solicite sincronização inicial ao carregar interface
RegisterNetEvent("vanguard:state:requestSync", function()
    local src = source
    local snapshot = StateManager.getSnapshot(src)
    TriggerClientEvent("vanguard:state:init", src, snapshot)
end)

-- Exports
exports('StateSet', function(source, key, value)
    return StateManager.set(source, key, value)
end)

exports('StateGet', function(source, key, defaultValue)
    return StateManager.get(source, key, defaultValue)
end)

exports('StatePatch', function(source, patchTable)
    return StateManager.patch(source, patchTable)
end)

exports('StateGetSnapshot', function(source)
    return StateManager.getSnapshot(source)
end)

VanguardState = StateManager

print("^5[Vanguard] Lib: State Manager (Server) loaded.^0")
