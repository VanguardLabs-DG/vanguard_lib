-- =========================================================================
-- VANGUARD LIBRARY v2.x | client/security_token.lua
-- Ponte de Segurança Cliente / NUI para Obtenção de One-Time Tokens
-- =========================================================================

local ClientSecurity = {}

--- Solicita um token de uso único ao servidor para uma dada ação
--- @param actionName string Nome da ação sensível (ex: "concessionaria:comprar")
--- @return string | nil token
function ClientSecurity.requestToken(actionName)
    if not actionName or actionName == "" then return nil end

    if lib and lib.callback then
        return lib.callback.await("vanguard:security:requestToken", false, actionName)
    end

    return exports.vanguard_lib:TriggerServerCallback("vanguard:security:requestToken", actionName)
end

--- Dispara um evento de servidor assinado com token descartável automático
--- @param eventName string
--- @param ... any
--- @return boolean
function ClientSecurity.triggerSecuredServerEvent(eventName, ...)
    local token = ClientSecurity.requestToken(eventName)
    if not token then
        print(string.format("^1[Vanguard Security] Falha ao obter token descartável para '%s'. Evento cancelado.^0", eventName))
        return false
    end

    TriggerServerEvent(eventName, token, ...)
    return true
end

-- =========================================================================
-- NUI CALLBACK BRIDGE
-- Permite que microfrontends NUI (iframes) solicitem tokens descartáveis
-- =========================================================================

RegisterNUICallback("vanguard:security:requestToken", function(data, cb)
    local action = data and (data.action or data.actionName)
    if not action then
        cb({ token = nil, error = "Ação não informada" })
        return
    end

    local token = ClientSecurity.requestToken(action)
    cb({ token = token })
end)

-- Exports
exports('RequestSecurityToken', function(actionName)
    return ClientSecurity.requestToken(actionName)
end)

exports('TriggerSecuredServerEvent', function(eventName, ...)
    return ClientSecurity.triggerSecuredServerEvent(eventName, ...)
end)

VanguardClientSecurity = ClientSecurity

print("^5[Vanguard] Lib: Security Token Client loaded.^0")
