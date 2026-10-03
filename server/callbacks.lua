-- ============================================================
-- Vanguard Library | server/callbacks.lua
-- Ponte de compatibilidade para callbacks de servidor usando ox_lib.
-- ============================================================

--- Regista um callback no servidor para responder a pedidos do cliente.
--- @param name string Nome do callback
--- @param cb function Função callback: function(source, cbRef, ...)
function RegisterServerCallback(name, cb)
    lib.callback.register(name, function(source, ...)
        local p = promise.new()
        local isResolved = false

        -- Timeout de segurança para evitar vazamento de coroutine / promise pendente
        SetTimeout(10000, function()
            if not isResolved then
                isResolved = true
                p:resolve({ false, "CALLBACK_TIMEOUT" })
            end
        end)

        local args = { ... }
        local success, err = pcall(function()
            cb(source, function(...)
                if not isResolved then
                    isResolved = true
                    p:resolve({ ... })
                end
            end, table.unpack(args))
        end)

        if not success and not isResolved then
            isResolved = true
            print(string.format("^1[Vanguard Lib] Erro no callback '%s': %s^0", tostring(name), tostring(err)))
            p:resolve({ false, "CALLBACK_INTERNAL_ERROR" })
        end

        local result = Citizen.Await(p)
        if type(result) == "table" then
            return table.unpack(result)
        end
        return result
    end)
end

print("^5[Vanguard] Lib: server callbacks loaded.^0")
