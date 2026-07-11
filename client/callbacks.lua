-- ============================================================
-- Vanguard Library | client/callbacks.lua
-- Ponte de compatibilidade para callbacks de cliente usando ox_lib.
-- ============================================================

--- Dispara um callback no servidor de forma síncrona e aguarda a resposta.
--- @param name string Nome do callback
--- @param ... any Argumentos adicionais
--- @return any
function TriggerServerCallback(name, ...)
    return lib.callback.await(name, false, ...)
end

print("^5[Vanguard] Lib: client callbacks loaded.^0")
