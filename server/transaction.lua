-- =========================================================================
-- VANGUARD LIBRARY v2.x | server/transaction.lua
-- Gerenciador de Transações Atômicas com Rollback (Padrão Saga / ACID FiveM)
-- Garante consistência em operações distribuídas (Player / Inventário / MySQL)
-- =========================================================================

local activeLocks = {} -- [lockKey] = { holder = source, expire = os.time() + seconds }
local TransactionManager = {}

-- =========================================================================
-- 1. MUTEX & LOCK MANAGER (Anti-Race Condition)
-- =========================================================================

--- Adquire uma trava exclusiva para uma chave ou jogador.
--- @param lockKey string Identificador da trava (ex: "player:1" ou "veh:ABC1234")
--- @param holder any Identificador do detentor da trava (tx.id ou string)
--- @param timeoutMs? number Tempo máximo de retenção da trava (padrão: 5000ms)
--- @param source? number | string Server ID associado (opcional para rastreamento de desconexão)
--- @return boolean acquired
function TransactionManager.acquireLock(lockKey, holder, timeoutMs, source)
    timeoutMs = timeoutMs or 5000
    local now = GetGameTimer()
    local existing = activeLocks[lockKey]

    if existing and existing.expire > now then
        if existing.holder == holder then
            -- Reentrante para a mesma transação/holder
            existing.expire = now + timeoutMs
            return true
        end
        return false -- Bloqueado por outra operação
    end

    activeLocks[lockKey] = {
        holder = holder,
        src = source and tonumber(source) or nil,
        expire = now + timeoutMs
    }
    return true
end

--- Libera uma trava previamente adquirida.
--- @param lockKey string
--- @param holder? any
function TransactionManager.releaseLock(lockKey, holder)
    local existing = activeLocks[lockKey]
    if not existing then return end
    if not holder or existing.holder == holder then
        activeLocks[lockKey] = nil
    end
end

-- Limpeza preventiva de travas no logout do jogador (previne vazamentos por coerção de tipo string/number)
AddEventHandler("playerDropped", function()
    local src = source
    local strSrc = tostring(src)
    local numSrc = tonumber(src)
    local playerKey = "player:" .. strSrc

    activeLocks[playerKey] = nil
    for key, data in pairs(activeLocks) do
        if data.src and (data.src == src or data.src == numSrc or tostring(data.src) == strSrc) then
            activeLocks[key] = nil
        elseif data.holder == src or data.holder == numSrc or tostring(data.holder) == strSrc then
            activeLocks[key] = nil
        end
    end
end)

-- =========================================================================
-- 2. TRANSACTION CONTEXT (Objeto tx)
-- =========================================================================

local function createTransactionContext(options)
    local tx = {
        id = exports.vanguard_lib:GenerateId(),
        label = options.label or "unnamed_tx",
        source = options.source,
        steps = {},
        executedStack = {},
        state = "pending", -- "pending" | "running" | "committed" | "rolled_back" | "failed"
        lockKey = nil,
    }

    --- Registra e executa um passo customizado com compensação
    --- @param stepDef table { name = string, execute = function, compensate = function }
    --- @return any result Resultado retornado pela função execute
    function tx:step(stepDef)
        if tx.state == "rolling_back" or tx.state == "rolled_back" or tx.state == "failed" then
            error(string.format("Tentativa de executar passo '%s' em transação abortada/em rollback.", tostring(stepDef.name)))
        end

        local stepName = stepDef.name or ("step_" .. (#tx.executedStack + 1))
        local execFn = stepDef.execute
        local compFn = stepDef.compensate

        if type(execFn) ~= "function" then
            error(string.format("Passo '%s' não possui função 'execute' válida.", stepName))
        end

        local execOk, res, errDetail = pcall(execFn, tx)
        if not execOk or res == false then
            local failureReason = errDetail or (res == false and "Execution returned false") or tostring(res)
            tx.failedStep = stepName
            tx.failureReason = failureReason
            error({
                isTxFailure = true,
                step = stepName,
                message = failureReason
            })
        end

        -- Registra na pilha LIFO para compensação se passos futuros falharem
        table.insert(tx.executedStack, {
            name = stepName,
            result = res,
            compensate = compFn
        })

        return res
    end

    --- Passo de débito financeiro com compensação nativa
    --- @param moneyType string "bank" | "cash"
    --- @param amount number
    --- @param reason? string
    --- @return boolean
    function tx:removeMoney(moneyType, amount, reason)
        local src = tx.source
        if not src then
            error("tx:removeMoney requer 'source' configurado nas opções da transação.")
        end

        local actionReason = reason or string.format("tx:%s:removeMoney", tx.label)
        local refundReason = string.format("estorno_tx:%s (%s)", tx.label, actionReason)

        return tx:step({
            name = "removeMoney:" .. moneyType,
            execute = function()
                local currentBalance = exports.vanguard_lib:GetPlayerMoney(src, moneyType)
                if currentBalance < amount then
                    return false, string.format("Saldo insuficiente em %s (possui: %s, necessário: %s)", moneyType, currentBalance, amount)
                end
                local ok = exports.vanguard_lib:RemoveMoney(src, moneyType, amount, actionReason)
                if not ok then
                    return false, "Falha ao debitar saldo do jogador"
                end
                return true
            end,
            compensate = function()
                local ok = exports.vanguard_lib:AddMoney(src, moneyType, amount, refundReason)
                if not ok then
                    error(string.format("Falha crítica ao estornar %s de %s para jogador [%s]", tostring(amount), moneyType, tostring(src)))
                end
            end
        })
    end

    --- Passo de crédito financeiro com compensação nativa
    --- @param moneyType string "bank" | "cash"
    --- @param amount number
    --- @param reason? string
    --- @return boolean
    function tx:addMoney(moneyType, amount, reason)
        local src = tx.source
        if not src then
            error("tx:addMoney requer 'source' configurado nas opções da transação.")
        end

        local actionReason = reason or string.format("tx:%s:addMoney", tx.label)
        local revertReason = string.format("estorno_tx:%s (%s)", tx.label, actionReason)

        return tx:step({
            name = "addMoney:" .. moneyType,
            execute = function()
                local ok = exports.vanguard_lib:AddMoney(src, moneyType, amount, actionReason)
                if not ok then
                    return false, "Falha ao creditar saldo para o jogador"
                end
                return true
            end,
            compensate = function()
                local ok = exports.vanguard_lib:RemoveMoney(src, moneyType, amount, revertReason)
                if not ok then
                    error(string.format("Falha crítica ao estornar crédito de %s de %s para jogador [%s]", tostring(amount), moneyType, tostring(src)))
                end
            end
        })
    end

    --- Passo de entrega de item no inventário (ox_inventory / QBX) com compensação nativa
    --- @param item string Nome do item
    --- @param count number Quantidade
    --- @param metadata? table Metadados do item
    --- @param slot? number Slot opcional
    --- @return boolean
    function tx:addItem(item, count, metadata, slot)
        local src = tx.source
        if not src then
            error("tx:addItem requer 'source' configurado nas opções da transação.")
        end

        count = count or 1

        return tx:step({
            name = "addItem:" .. item,
            execute = function()
                -- Validação prévia de capacidade de carga se ox_inventory estiver disponível
                local hasOx = GetResourceState('ox_inventory') == 'started'
                if hasOx then
                    local canCarry = exports.ox_inventory:CanCarryItem(src, item, count, metadata)
                    if not canCarry then
                        return false, "Inventário cheio ou acima do limite de peso"
                    end
                end

                local success = false
                if hasOx then
                    success = exports.ox_inventory:AddItem(src, item, count, metadata, slot) and true or false
                else
                    -- Fallback para QBX Core Functions
                    local player = exports.vanguard_lib:GetPlayer(src)
                    if player and player.Functions and player.Functions.AddItem then
                        success = player.Functions.AddItem(item, count, slot, metadata) and true or false
                    end
                end

                if not success then
                    return false, "Falha ao adicionar item ao inventário"
                end
                return true
            end,
            compensate = function()
                local removed = false
                if GetResourceState('ox_inventory') == 'started' then
                    removed = exports.ox_inventory:RemoveItem(src, item, count, metadata, slot) and true or false
                else
                    local player = exports.vanguard_lib:GetPlayer(src)
                    if player and player.Functions and player.Functions.RemoveItem then
                        removed = player.Functions.RemoveItem(item, count, slot) and true or false
                    end
                end

                if not removed then
                    error(string.format("Falha crítica ao compensar addItem: não foi possível remover %s (x%s) do inventário do jogador [%s]", item, tostring(count), tostring(src)))
                end
            end
        })
    end

    --- Passo de remoção de item do inventário com compensação nativa
    --- @param item string Nome do item
    --- @param count number Quantidade
    --- @param metadata? table Metadados do item
    --- @param slot? number Slot opcional
    --- @return boolean
    function tx:removeItem(item, count, metadata, slot)
        local src = tx.source
        if not src then
            error("tx:removeItem requer 'source' configurado nas opções da transação.")
        end

        count = count or 1

        return tx:step({
            name = "removeItem:" .. item,
            execute = function()
                local hasOx = GetResourceState('ox_inventory') == 'started'
                local success = false
                if hasOx then
                    success = exports.ox_inventory:RemoveItem(src, item, count, metadata, slot) and true or false
                else
                    local player = exports.vanguard_lib:GetPlayer(src)
                    if player and player.Functions and player.Functions.RemoveItem then
                        success = player.Functions.RemoveItem(item, count, slot) and true or false
                    end
                end

                if not success then
                    return false, "Item não encontrado ou quantidade insuficiente no inventário"
                end
                return true
            end,
            compensate = function()
                local added = false
                if GetResourceState('ox_inventory') == 'started' then
                    added = exports.ox_inventory:AddItem(src, item, count, metadata, slot) and true or false
                else
                    local player = exports.vanguard_lib:GetPlayer(src)
                    if player and player.Functions and player.Functions.AddItem then
                        added = player.Functions.AddItem(item, count, slot, metadata) and true or false
                    end
                end

                if not added then
                    error(string.format("Falha crítica ao compensar removeItem: não foi possível devolver %s (x%s) ao inventário do jogador [%s]", item, tostring(count), tostring(src)))
                end
            end
        })
    end

    --- Passo de inserção no banco de dados com compensação automática por exclusão de ID
    --- @param query string Query INSERT
    --- @param params table Parâmetros da query
    --- @param tableOrCompensate string | function Nome da tabela para DELETE ou função customizada
    --- @return number | nil insertId
    function tx:dbInsert(query, params, tableOrCompensate)
        return tx:step({
            name = "dbInsert",
            execute = function()
                local insertId = MySQL.insert.await(query, params)
                if not insertId or insertId <= 0 then
                    return false, "Falha ao executar INSERT no banco de dados"
                end
                return insertId
            end,
            compensate = function(insertId)
                if not insertId then return end
                if type(tableOrCompensate) == "string" then
                    if not tableOrCompensate:match("^[%w_]+$") then
                        error(string.format("Nome de tabela inválido na compensação dbInsert: '%s'", tostring(tableOrCompensate)))
                    end
                    MySQL.query.await(string.format("DELETE FROM `%s` WHERE id = ?", tableOrCompensate), { insertId })
                elseif type(tableOrCompensate) == "function" then
                    tableOrCompensate(insertId)
                end
            end
        })
    end

    --- Aborta a transação propositalmente com mensagem explicativa
    --- @param reason string
    function tx:fail(reason)
        error({
            isTxFailure = true,
            step = "explicit_abort",
            message = reason or "Transação abortada pelo desenvolvedor"
        })
    end

    return tx
end

-- =========================================================================
-- 3. ORQUESTRADOR PRINCIPAL (vanguard.transaction.run)
-- =========================================================================

--- Executa um bloco transacional com garantia de rollback LIFO caso qualquer etapa falhe.
--- @param options table { source?, label?, timeout?, lock?, lockKey?, onRollback?, onCommit? }
--- @param handler function function(tx) -> result
--- @return boolean success, any result, table | nil errInfo
function TransactionManager.run(options, handler)
    if type(options) == "function" then
        handler = options
        options = {}
    end
    options = options or {}

    local src = options.source
    local lockKey = options.lockKey or (src and ("player:" .. tostring(src)) or nil)
    local useLock = options.lock ~= false and lockKey ~= nil

    local tx = createTransactionContext(options)
    tx.lockKey = lockKey
    tx.state = "running"

    -- 1. Controle de concorrência (Mutex com Fencing Token tx.id)
    if useLock then
        local acquired = TransactionManager.acquireLock(lockKey, tx.id, options.timeout or 6000, src)
        if not acquired then
            return false, nil, {
                message = "Operação bloqueada: outra transação já está em andamento para este jogador.",
                step = "acquire_lock",
                code = "LOCKED"
            }
        end
    end

    -- 2. Execução protegida do bloco transacional
    local execSuccess, execResult = pcall(handler, tx)

    -- 3. Caso de Falha: Executa Rollback em ordem LIFO (reversa)
    if not execSuccess or (type(execResult) == "table" and execResult.isTxFailure) then
        tx.state = "rolling_back"
        local errInfo = type(execResult) == "table" and execResult.isTxFailure and execResult or {
            message = tostring(execResult),
            step = tx.failedStep or "runtime_error"
        }

        print(string.format("^3[Vanguard TX] Falha na transação '%s' (ID: %s). Iniciando Rollback de %d etapas...^0",
            tx.label, tx.id, #tx.executedStack))

        local compensationErrors = {}

        -- Desbobina a pilha em ordem LIFO
        for i = #tx.executedStack, 1, -1 do
            local stepData = tx.executedStack[i]
            if stepData.compensate and type(stepData.compensate) == "function" then
                local compOk, compErr = pcall(stepData.compensate, stepData.result)
                if not compOk then
                    local errMsg = string.format("Erro ao compensar etapa '%s': %s", stepData.name, tostring(compErr))
                    table.insert(compensationErrors, errMsg)
                    print(string.format("^1[Vanguard TX CRITICAL] %s^0", errMsg))
                end
            end
        end

        tx.state = "rolled_back"

        -- Se houver falha na própria compensação, dispara alerta de emergência no Discord
        if #compensationErrors > 0 then
            tx.state = "failed"
            if exports.vanguard_lib and exports.vanguard_lib.DiscordLog then
                exports.vanguard_lib:DiscordLog({
                    channel = "anticheat",
                    priority = "urgent",
                    embed = {
                        title = "🚨 FALHA CRÍTICA DE ROLLBACK NA TRANSAÇÃO",
                        description = string.format("Transação **%s** (ID: `%s`) falhou e gerou inconsistência de compensação!", tx.label, tx.id),
                        color = 0xef4444,
                        fields = {
                            { name = "Player Source", value = tostring(src or "N/A"), inline = true },
                            { name = "Motivo da Falha", value = tostring(errInfo.message), inline = false },
                            { name = "Erros de Compensação", value = table.concat(compensationErrors, "\n"), inline = false }
                        }
                    }
                })
            end
        end

        if options.onRollback and type(options.onRollback) == "function" then
            pcall(options.onRollback, errInfo, tx)
        end

        if useLock then
            TransactionManager.releaseLock(lockKey, tx.id)
        end

        return false, nil, errInfo
    end

    -- 4. Caso de Sucesso: Commit da transação
    tx.state = "committed"

    if options.onCommit and type(options.onCommit) == "function" then
        pcall(options.onCommit, execResult, tx)
    end

    if useLock then
        TransactionManager.releaseLock(lockKey, tx.id)
    end

    return true, execResult, nil
end

-- =========================================================================
-- 4. EXPORTS
-- =========================================================================

exports('TransactionRun', function(options, handler)
    return TransactionManager.run(options, handler)
end)

exports('TransactionAcquireLock', function(lockKey, holder, timeoutMs)
    return TransactionManager.acquireLock(lockKey, holder, timeoutMs)
end)

exports('TransactionReleaseLock', function(lockKey, holder)
    return TransactionManager.releaseLock(lockKey, holder)
end)

VanguardTransaction = TransactionManager

print("^5[Vanguard] Lib: Transaction Manager (ACID FiveM) loaded.^0")
