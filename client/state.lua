-- =========================================================================
-- VANGUARD LIBRARY v2.x | client/state.lua
-- Gerenciador de Estado no Cliente e Ponte com Microfrontends NUI
-- =========================================================================

local ClientState = {}

local ClientStateManager = {}

--- Retorna o valor de uma chave no estado local do cliente
--- @param key string
--- @param defaultValue? any
--- @return any
function ClientStateManager.get(key, defaultValue)
    if not key or key == "" then return ClientState end
    local val = ClientState[key]
    return val ~= nil and val or defaultValue
end

--- Define localmente e notifica a interface NUI
--- @param key string
--- @param value any
function ClientStateManager.set(key, value)
    ClientState[key] = value

    -- Envia para o NUI (vanguard_esc e iframes)
    SendNUIMessage({
        type = "mri-state/sync",
        path = key,
        value = value,
        patch = { [key] = value }
    })
end

--- Atualiza múltiplas chaves no estado do cliente
--- @param patchTable table
function ClientStateManager.patch(patchTable)
    if not patchTable or type(patchTable) ~= "table" then return end
    for k, v in pairs(patchTable) do
        ClientState[k] = v
    end

    SendNUIMessage({
        type = "mri-state/sync",
        patch = patchTable
    })
end

--- Retorna todo o snapshot local
--- @return table
function ClientStateManager.getSnapshot()
    return ClientState
end

-- =========================================================================
-- EVENTOS DE REDE & NUI
-- =========================================================================

-- Sincronização incremental recebida do servidor
RegisterNetEvent("vanguard:state:sync", function(patchTable)
    if not patchTable or type(patchTable) ~= "table" then return end
    ClientStateManager.patch(patchTable)
end)

-- Inicialização completa do estado ao conectar (mescla preservando estado local prévio)
RegisterNetEvent("vanguard:state:init", function(fullSnapshot)
    if not fullSnapshot or type(fullSnapshot) ~= "table" then return end
    for k, v in pairs(fullSnapshot) do
        ClientState[k] = v
    end

    SendNUIMessage({
        type = "mri-state/sync",
        patch = fullSnapshot
    })
end)

-- Solicita sincronização inicial do servidor assim que o jogador spawna
AddEventHandler("playerSpawned", function()
    TriggerServerEvent("vanguard:state:requestSync")
end)

-- Sincronização de inicialização caso o recurso seja reiniciado com jogador em sessão
Citizen.CreateThread(function()
    Citizen.Wait(500)
    TriggerServerEvent("vanguard:state:requestSync")
end)

-- NUI Callback para quando um microfrontend ou o ESC altera o estado
RegisterNUICallback("vanguard:state:patch", function(data, cb)
    if data and type(data) == "table" then
        for k, v in pairs(data) do
            ClientState[k] = v
        end
    end
    cb({ ok = true })
end)

-- Exports
exports('StateGet', function(key, defaultValue)
    return ClientStateManager.get(key, defaultValue)
end)

exports('StateSet', function(key, value)
    return ClientStateManager.set(key, value)
end)

exports('StatePatch', function(patchTable)
    return ClientStateManager.patch(patchTable)
end)

exports('StateGetSnapshot', function()
    return ClientStateManager.getSnapshot()
end)

VanguardClientState = ClientStateManager

print("^5[Vanguard] Lib: State Manager (Client) loaded.^0")
