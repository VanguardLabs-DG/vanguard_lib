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

        cb(source, function(...)
            p:resolve({...})
        end, ...)

        local result = Citizen.Await(p)
        return table.unpack(result)
    end)
end

print("^5[Vanguard] Lib: server callbacks loaded.^0")
