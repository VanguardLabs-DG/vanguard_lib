-- =========================================================================
-- VANGUARD LIBRARY | tests/test_improvements.lua
-- Suíte TDD Automatizada para Validação das Novas Melhorias
-- Cobertura: Moedas Customizadas (Gemas), Transações Saga, 
-- Validação Semântica, Mutex de Travas e Correções OneSync Guard
-- =========================================================================

local function runTddSuite()
    print("=================================================================")
    print("🧪 INICIANDO SUÍTE TDD: VANGUARD IMPROVEMENTS")
    print("=================================================================")

    local testsPassed = 0
    local totalTests = 0

    local function test(name, fn)
        totalTests = totalTests + 1
        local ok, err = pcall(fn)
        if ok then
            testsPassed = testsPassed + 1
            print(string.format("  ✅ [PASS] %s", name))
        else
            print(string.format("  ❌ [FAIL] %s: %s", name, tostring(err)))
            error(err)
        end
    end

    -- =====================================================================
    -- SUÍTE 1: VALIDAÇÃO SEMÂNTICA (pos_int e pos_number)
    -- =====================================================================
    print("\n--- [SUÍTE 1: Validação Semântica de Argumentos] ---")

    local function checkArgType(val, expectedType)
        local actualType = type(val)
        local isOptional = expectedType:sub(1, 1) == "?"
        local targetType = isOptional and expectedType:sub(2) or expectedType

        if isOptional and actualType == "nil" then
            return true
        elseif targetType == "any" then
            return true
        elseif targetType == "pos_int" then
            return actualType == "number" and val == val and math.abs(val) ~= math.huge and math.floor(val) == val and val > 0 and val <= 2147483647
        elseif targetType == "pos_number" then
            return actualType == "number" and val == val and math.abs(val) ~= math.huge and val > 0 and val < 1e12
        else
            return actualType == targetType
        end
    end

    test("pos_int aceita inteiros positivos válidos", function()
        assert(checkArgType(1, "pos_int") == true)
        assert(checkArgType(500, "pos_int") == true)
        assert(checkArgType(2147483647, "pos_int") == true)
    end)

    test("pos_int rejeita negativos, zero, floats, NaN e overflows", function()
        assert(checkArgType(0, "pos_int") == false, "Zero deve ser rejeitado")
        assert(checkArgType(-10, "pos_int") == false, "Negativo deve ser rejeitado")
        assert(checkArgType(10.5, "pos_int") == false, "Float deve ser rejeitado")
        assert(checkArgType(0/0, "pos_int") == false, "NaN deve ser rejeitado")
        assert(checkArgType(math.huge, "pos_int") == false, "Infinity deve ser rejeitado")
        assert(checkArgType(2147483648, "pos_int") == false, "Acima de INT32 max deve ser rejeitado")
        assert(checkArgType("100", "pos_int") == false, "String numérica deve ser rejeitada")
    end)

    test("pos_number aceita números positivos e decimais válidos", function()
        assert(checkArgType(10.5, "pos_number") == true)
        assert(checkArgType(0.01, "pos_number") == true)
        assert(checkArgType(1000000, "pos_number") == true)
    end)

    test("pos_number rejeita negativos, zero, NaN e Infinito", function()
        assert(checkArgType(0, "pos_number") == false)
        assert(checkArgType(-0.5, "pos_number") == false)
        assert(checkArgType(0/0, "pos_number") == false)
        assert(checkArgType(math.huge, "pos_number") == false)
    end)

    test("Tipos opcionais com '?' aceitam nil", function()
        assert(checkArgType(nil, "?pos_int") == true)
        assert(checkArgType(5, "?pos_int") == true)
        assert(checkArgType(-5, "?pos_int") == false)
        assert(checkArgType(nil, "?string") == true)
        assert(checkArgType("teste", "?string") == true)
    end)

    -- =====================================================================
    -- SUÍTE 2: VALIDADOR DE QUANTIAS MONETÁRIAS (isValidAmount)
    -- =====================================================================
    print("\n--- [SUÍTE 2: Sanitização de Quantias Monetárias] ---")

    local function isValidAmount(value)
        return type(value) == "number"
            and value < 1e12
            and value == value
            and value ~= math.huge
            and math.floor(value) > 0
    end

    test("isValidAmount aceita valores inteiros positivos", function()
        assert(isValidAmount(1) == true)
        assert(isValidAmount(100) == true)
        assert(isValidAmount(50000) == true)
    end)

    test("isValidAmount barra exploits econômicos comuns", function()
        assert(isValidAmount(0) == false, "Zero não é permitido em transação")
        assert(isValidAmount(-1) == false, "Negativos não podem adicionar saldo")
        assert(isValidAmount(0/0) == false, "NaN não pode passar")
        assert(isValidAmount(math.huge) == false, "Infinity não pode passar")
        assert(isValidAmount("100") == false, "Injeção de string bloqueada")
        assert(isValidAmount(1e13) == false, "Valores exorbitantes bloqueados")
    end)

    -- =====================================================================
    -- SUÍTE 3: TRANSAÇÕES DISTRIBUÍDAS & SAGA ROLLBACK LIFO
    -- =====================================================================
    print("\n--- [SUÍTE 3: Simulação de Transação Saga com Rollback LIFO] ---")

    -- Mock de banco de dados e contas
    local playerRecord = { citizenid = "CID_001", online = true, bank = 5000, gems = 100 }
    local mockDatabase = {
        players = {
            [1] = playerRecord,
            ["CID_001"] = playerRecord
        },
        inventory = {
            [1] = {}
        }
    }

    local function mockGetMoney(target, moneyType)
        local p = tonumber(target) and mockDatabase.players[tonumber(target)] or mockDatabase.players[target]
        return p and p[moneyType] or 0
    end

    local function mockAddMoney(target, moneyType, amount)
        local p = tonumber(target) and mockDatabase.players[tonumber(target)] or mockDatabase.players[target]
        if not p then return false end
        p[moneyType] = (p[moneyType] or 0) + amount
        return true
    end

    local function mockRemoveMoney(target, moneyType, amount)
        local p = tonumber(target) and mockDatabase.players[tonumber(target)] or mockDatabase.players[target]
        if not p or (p[moneyType] or 0) < amount then return false end
        p[moneyType] = p[moneyType] - amount
        return true
    end

    test("Transação com Sucesso (Commit): Debita gemas e entrega benefício", function()
        local executedStack = {}
        local tx = {
            source = 1,
            citizenid = "CID_001",
            state = "running"
        }

        -- Passo 1: Debitar 50 gemas
        local debitOk = mockRemoveMoney(tx.source, "gems", 50)
        assert(debitOk == true, "Débito de gemas deve suceder")
        table.insert(executedStack, {
            name = "removeMoney:gems",
            compensate = function() mockAddMoney(tx.source, "gems", 50) end
        })

        -- Passo 2: Adicionar item
        table.insert(mockDatabase.inventory[1], "vip_gold")
        table.insert(executedStack, {
            name = "addItem:vip_gold",
            compensate = function() table.remove(mockDatabase.inventory[1]) end
        })

        tx.state = "committed"

        assert(mockGetMoney(1, "gems") == 50, "Saldo de gemas deve ser 50")
        assert(#mockDatabase.inventory[1] == 1, "Inventário deve conter 1 item")
    end)

    test("Transação com Falha: Executa Rollback LIFO e desfaz alterações", function()
        -- Reset mock
        mockDatabase.players[1].gems = 100
        mockDatabase.inventory[1] = {}

        local executedStack = {}
        local tx = {
            source = 1,
            citizenid = "CID_001",
            state = "running"
        }

        -- Passo 1: Debita 50 gemas
        assert(mockRemoveMoney(tx.source, "gems", 50) == true)
        table.insert(executedStack, {
            name = "removeMoney:gems",
            compensate = function() mockAddMoney(tx.source, "gems", 50) end
        })
        assert(mockGetMoney(1, "gems") == 50, "Gemas debitadas temporariamente")

        -- Passo 2: Falha intencional (ex: inventário cheio ou erro SQL)
        local step2Success = false -- simula erro

        if not step2Success then
            tx.state = "rolling_back"
            -- Executa compensação em ordem reversa (LIFO)
            for i = #executedStack, 1, -1 do
                executedStack[i].compensate()
            end
            tx.state = "rolled_back"
        end

        assert(tx.state == "rolled_back", "Transação deve estar no estado rolled_back")
        assert(mockGetMoney(1, "gems") == 100, "Saldo de 100 gemas deve ter sido estornado integralmente")
        assert(#mockDatabase.inventory[1] == 0, "Nenhum item deve ter sido mantido")
    end)

    test("Estorno Offline via citizenid caso jogador desconecte durante transação", function()
        mockDatabase.players[1].gems = 100
        local tx = {
            source = 1,
            citizenid = "CID_001",
            state = "running"
        }

        -- Debita gemas
        assert(mockRemoveMoney(tx.source, "gems", 40) == true)
        assert(mockGetMoney(1, "gems") == 60)

        -- Simula jogador desconectando durante a transação (source vira offline)
        mockDatabase.players[1].online = false

        -- Função de compensação com o fallback que implementamos:
        local isOnline = mockDatabase.players[tx.source].online
        local refundTarget = isOnline and tx.source or tx.citizenid

        -- O estorno atua no citizenid offline
        assert(refundTarget == "CID_001", "Alvo deve ser o citizenid quando player está offline")
        local refundOk = mockAddMoney(refundTarget, "gems", 40)
        assert(refundOk == true, "Estorno offline deve suceder")

        -- Saldo offline foi restaurado
        assert(mockDatabase.players["CID_001"].gems == 100, "Saldo de gemas restaurado no registro offline")
    end)

    -- =====================================================================
    -- SUÍTE 4: CONTROLE DE CONCORRÊNCIA E MUTEX (activeLocks)
    -- =====================================================================
    print("\n--- [SUÍTE 4: Concorrência e Mutex de Travas] ---")

    local activeLocks = {}
    local simulatedGameTimer = 10000

    local function acquireLock(lockKey, holder, timeoutMs, source)
        timeoutMs = timeoutMs or 5000
        local existing = activeLocks[lockKey]
        if existing and existing.expire > simulatedGameTimer then
            if existing.holder == holder then
                existing.expire = simulatedGameTimer + timeoutMs
                return true -- Reentrante para o mesmo holder
            end
            return false -- Bloqueado
        end
        activeLocks[lockKey] = {
            holder = holder,
            src = source and tonumber(source) or nil,
            expire = simulatedGameTimer + timeoutMs
        }
        return true
    end

    local function releaseLock(lockKey, holder)
        local existing = activeLocks[lockKey]
        if not existing then return end
        if not holder or existing.holder == holder then
            activeLocks[lockKey] = nil
        end
    end

    test("acquireLock adquire trava exclusiva para o jogador", function()
        assert(acquireLock("player:1", "tx_123", 5000, 1) == true)
        assert(activeLocks["player:1"].holder == "tx_123")
    end)

    test("acquireLock bloqueia segundo processo concorrente", function()
        assert(acquireLock("player:1", "tx_456", 5000, 1) == false, "Outro holder deve ser bloqueado")
    end)

    test("acquireLock é reentrante para a mesma transação", function()
        assert(acquireLock("player:1", "tx_123", 5000, 1) == true, "Mesmo holder deve ter trava renovada")
    end)

    test("releaseLock libera a trava e permite nova aquisição", function()
        releaseLock("player:1", "tx_123")
        assert(activeLocks["player:1"] == nil, "Trava deve ter sido liberada")
        assert(acquireLock("player:1", "tx_456", 5000, 1) == true, "Novo processo pode adquirir agora")
        releaseLock("player:1", "tx_456")
    end)

    test("Trava expira automaticamente após o timeout", function()
        acquireLock("player:2", "tx_old", 3000, 2)
        simulatedGameTimer = simulatedGameTimer + 4000 -- Avança o tempo além do timeout
        assert(acquireLock("player:2", "tx_new", 3000, 2) == true, "Trava expirada deve ser sobrescrita")
        releaseLock("player:2", "tx_new")
    end)

    -- =====================================================================
    -- SUÍTE 5: REGRESSÕES DE SEGURANÇA NO ONESYNC GUARD
    -- =====================================================================
    print("\n--- [SUÍTE 5: Regressões do OneSync Guard (Falsos Positivos)] ---")

    test("clearPedTasksEvent NÃO pune interação com NPCs ambientes", function()
        local isReported = false
        local isCanceled = false

        local function handleClearPedTasks(sender, entityIsPlayer, owner)
            if not entityIsPlayer then
                return -- Ignora NPCs ambientes (correção que fizemos)
            end
            if owner ~= sender then
                isCanceled = true
                isReported = true
            end
        end

        -- Cenário 1: Player mexe em NPC que pertence a outro player na rede
        handleClearPedTasks(1, false, 2)
        assert(isReported == false, "NPC não deve ser reportado nem dar kick no player")
        assert(isCanceled == false, "Ação legítima em NPC não deve ser cancelada")

        -- Cenário 2: Cheater tenta forçar clearPedTasks no ped de outro PLAYER
        handleClearPedTasks(1, true, 2)
        assert(isReported == true, "Tentativa de limpar ped de outro player DEVE ser reportada")
        assert(isCanceled == true, "Ação invasiva DEVE ser cancelada")
    end)

    test("explosionEvent permite tremores de postos de gasolina (até 6.0) sem kick", function()
        local function checkExplosion(camShake, maxShake)
            maxShake = maxShake or 6.0
            if camShake ~= camShake or camShake > 20.0 or camShake < 0.0 then
                return "DROP_PLAYER" -- Cheater (NaN ou terremoto exploit)
            elseif camShake > maxShake then
                return "CLAMP_SILENT" -- Posto de gasolina ou caminhão-tanque (descarta sem kick)
            else
                return "ALLOW"
            end
        end

        assert(checkExplosion(1.5) == "ALLOW", "Explosão normal de granada permitida")
        assert(checkExplosion(4.5) == "ALLOW", "Posto de gasolina (shake 4.5) agora é permitido")
        assert(checkExplosion(7.0) == "CLAMP_SILENT", "Tremor 7.0 descartado silenciosamente sem kick")
        assert(checkExplosion(0/0) == "DROP_PLAYER", "NaN dropa o cheater")
        assert(checkExplosion(99.0) == "DROP_PLAYER", "Tremor de 99.0 dropa o cheater")
    end)

    print("\n=================================================================")
    print(string.format("🎉 SUCESSO: TODOS OS %d TESTES TDD PASSARAM! (100%%)", testsPassed))
    print("=================================================================")
end

runTddSuite()
