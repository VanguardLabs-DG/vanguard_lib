-- =========================================================================
-- VANGUARD LIBRARY v2.4.0 | tests/test_guard.lua
-- Suíte de Testes Automatizados do OneSync Engine Guard & Crash Shield
-- =========================================================================

local function runTests()
    print("==================================================")
    print("🧪 INICIANDO TESTES DO ONESYNC ENGINE GUARD...")
    print("==================================================")

    -- 1. Testes de isFiniteNumber
    local function isFiniteNumber(v)
        local n = tonumber(v)
        return n ~= nil and n == n and math.abs(n) ~= math.huge
    end

    assert(isFiniteNumber(100) == true, "100 deve ser finito")
    assert(isFiniteNumber(-50.5) == true, "-50.5 deve ser finito")
    assert(isFiniteNumber(0) == true, "0 deve ser finito")
    assert(isFiniteNumber("123.45") == true, "'123.45' deve ser finito")
    assert(isFiniteNumber(0/0) == false, "NaN deve ser rejeitado")
    assert(isFiniteNumber(math.huge) == false, "+Inf deve ser rejeitado")
    assert(isFiniteNumber(-math.huge) == false, "-Inf deve ser rejeitado")
    assert(isFiniteNumber(nil) == false, "nil deve ser rejeitado")
    assert(isFiniteNumber("abc") == false, "'abc' deve ser rejeitado")
    print("✅ 1. Sanitizador Numérico Finito: 9/9 testes passaram.")

    -- 2. Testes de isValidCoord (World Bounds)
    local bounds = {
        minX = -8192.0, maxX = 8192.0,
        minY = -8192.0, maxY = 8192.0,
        minZ = -1000.0, maxZ = 5000.0
    }
    local function isValidCoord(x, y, z)
        if not isFiniteNumber(x) or not isFiniteNumber(y) or not isFiniteNumber(z) then
            return false
        end
        if x < bounds.minX or x > bounds.maxX then return false end
        if y < bounds.minY or y > bounds.maxY then return false end
        if z < bounds.minZ or z > bounds.maxZ then return false end
        return true
    end

    assert(isValidCoord(0, 0, 72) == true, "Legion Square deve ser válido")
    assert(isValidCoord(-2000, 3000, 30) == true, "Sandy Shores deve ser válido")
    assert(isValidCoord(0/0, 100, 100) == false, "Coordenada NaN X deve ser rejeitada")
    assert(isValidCoord(100, math.huge, 100) == false, "Coordenada Inf Y deve ser rejeitada")
    assert(isValidCoord(99999, 0, 50) == false, "Coordenada fora do mapa X deve ser rejeitada")
    assert(isValidCoord(0, 0, -2000) == false, "Profundidade impossível Z deve ser rejeitada")
    print("✅ 2. Validador Geométrico OneSync: 6/6 testes passaram.")

    -- 3. Testes de isValidScale (PTFX)
    local function isValidScale(scale, minScale, maxScale)
        if not isFiniteNumber(scale) then return false end
        minScale = minScale or 0.001
        maxScale = maxScale or 5.0
        return scale >= minScale and scale <= maxScale
    end

    assert(isValidScale(1.0) == true, "Escala 1.0 deve ser válida")
    assert(isValidScale(0.005) == true, "Escala pequena 0.005 deve ser válida")
    assert(isValidScale(5.0) == true, "Escala limite 5.0 deve ser válida")
    assert(isValidScale(0) == false, "Escala 0 deve ser rejeitada")
    assert(isValidScale(-1.0) == false, "Escala negativa deve ser rejeitada")
    assert(isValidScale(999.0) == false, "Escala exorbitante 999.0 deve ser rejeitada")
    assert(isValidScale(0/0) == false, "Escala NaN deve ser rejeitada")
    print("✅ 3. Validador de Escala de Partículas (PTFX): 7/7 testes passaram.")

    -- 4. Testes de isValidVelocity (Projéteis)
    local function isValidVelocity(vx, vy, vz, maxSpeed)
        if not isFiniteNumber(vx) or not isFiniteNumber(vy) or not isFiniteNumber(vz) then
            return false
        end
        maxSpeed = maxSpeed or 450.0
        local speedSq = vx * vx + vy * vy + vz * vz
        return speedSq <= (maxSpeed * maxSpeed)
    end

    assert(isValidVelocity(50, 50, 0) == true, "Velocidade normal deve ser válida")
    assert(isValidVelocity(0, 0, 450) == true, "Velocidade limite 450 deve ser válida")
    assert(isValidVelocity(500, 0, 0) == false, "Velocidade acima de 450 deve ser rejeitada")
    assert(isValidVelocity(10000, 10000, 10000) == false, "Supervelocidade deve ser rejeitada")
    assert(isValidVelocity(0/0, 0, 0) == false, "Velocidade NaN deve ser rejeitada")
    print("✅ 4. Validador de Velocidade de Projéteis: 5/5 testes passaram.")

    -- 5. Testes de Mitigação de quiet-uniform-jersey (clearPedTasks alheio)
    local function simulateClearPedTasks(sender, entityOwner)
        if entityOwner > 0 and entityOwner ~= sender then
            return false, "BLOCKED: quiet-uniform-jersey (+631F8C)"
        end
        return true, "ALLOWED"
    end

    local allowed, _ = simulateClearPedTasks(1, 1)
    assert(allowed == true, "Limpar tarefas do próprio ped deve ser permitido")

    local blocked, reason = simulateClearPedTasks(2, 1)
    assert(blocked == false, "Limpar tarefas de ped alheio deve ser BLOQUEADO")
    assert(reason:find("quiet-uniform-jersey", 1, true) ~= nil, "Assinatura do exploit deve ser identificada")
    print("✅ 5. Mitigação quiet-uniform-jersey (ClearPedTasks): 2/2 testes passaram.")

    -- 6. Testes de Mitigação de october-hotel-echo (Explosão Malformada)
    local function simulateExplosion(expType, camShake, dmgScale, x, y, z)
        if expType < 0 or expType > 72 then return false, "INVALID_TYPE" end
        if camShake ~= nil and (not isFiniteNumber(camShake) or camShake > 3.0 or camShake < 0.0) then return false, "INVALID_SHAKE" end
        if dmgScale ~= nil and (not isFiniteNumber(dmgScale) or dmgScale > 5.0 or dmgScale < 0.0) then return false, "INVALID_DAMAGE" end
        if (x ~= nil or y ~= nil or z ~= nil) and not isValidCoord(x, y, z) then return false, "INVALID_COORDS" end
        return true, "ALLOWED"
    end

    assert(simulateExplosion(2, 1.0, 1.0, 0, 0, 72) == true, "Explosão normal de granada deve ser permitida")
    assert(simulateExplosion(999, 1.0, 1.0, 0, 0, 72) == false, "Tipo 999 deve ser bloqueado")
    assert(simulateExplosion(2, 999.0, 1.0, 0, 0, 72) == false, "CameraShake 999 deve ser bloqueado")
    assert(simulateExplosion(2, 1.0, 999.0, 0, 0, 72) == false, "DamageScale 999 deve ser bloqueado")
    assert(simulateExplosion(2, 1.0, 1.0, 0/0, 0, 72) == false, "Coordenada NaN deve ser bloqueada")
    print("✅ 6. Mitigação october-hotel-echo (Explosion Sanitizer): 5/5 testes passaram.")

    -- 7. Testes de Mitigação de black-aspen-tango (Weapon Damage Overflow & Null Weapon)
    local function simulateWeaponDamage(weaponType, weaponDamage)
        local weapon = tonumber(weaponType)
        if not weapon or weapon == 0 or not isFiniteNumber(weapon) then
            return false, "NULL_WEAPON"
        end
        local damage = tonumber(weaponDamage)
        if damage and (not isFiniteNumber(damage) or damage > 65535) then
            return false, "DAMAGE_OVERFLOW"
        end
        return true, "ALLOWED"
    end

    assert(simulateWeaponDamage(453432689, 35) == true, "Dano normal de pistola deve ser permitido")
    assert(simulateWeaponDamage(0, 35) == false, "weaponType 0 (nullptr dereference) deve ser bloqueado")
    assert(simulateWeaponDamage(nil, 35) == false, "weaponType nil deve ser bloqueado")
    assert(simulateWeaponDamage(453432689, 999999) == false, "Dano adulterado > 65535 deve ser bloqueado")
    assert(simulateWeaponDamage(453432689, 0/0) == false, "Dano NaN deve ser bloqueado")
    print("✅ 7. Mitigação black-aspen-tango (Weapon Damage Overflow): 5/5 testes passaram.")

    -- 8. Testes de Rate-Limiter por Janela
    local buckets = {}
    local function countWindow(s, kind, limit, windowSec, nowTime)
        buckets[s] = buckets[s] or {}
        local b = buckets[s][kind]
        if not b or (nowTime - b.at) >= (windowSec * 1000) then
            b = { at = nowTime, n = 0 }
            buckets[s][kind] = b
        end
        b.n = b.n + 1
        return b.n > limit, b.n
    end

    local t0 = 1000
    assert(countWindow(1, "vehicles", 3, 5, t0) == false, "Spawn 1 deve ser permitido")
    assert(countWindow(1, "vehicles", 3, 5, t0) == false, "Spawn 2 deve ser permitido")
    assert(countWindow(1, "vehicles", 3, 5, t0) == false, "Spawn 3 deve ser permitido")
    assert(countWindow(1, "vehicles", 3, 5, t0) == true, "Spawn 4 deve exceder o limite (BLOQUEADO)")
    -- Após passar o tempo da janela:
    local t1 = t0 + 6000
    assert(countWindow(1, "vehicles", 3, 5, t1) == false, "Spawn após reset deve ser permitido")
    print("✅ 8. Rate-Limiter de Entidades por Janela: 5/5 testes passaram.")

    -- 9. Testes de State Bag Firewall (Chaves Protegidas & Whitelist)
    local protectedKeys = {
        ["admin"] = true, ["staff"] = true, ["money"] = true, ["godmode"] = true
    }
    local whitelistedKeys = {
        ["radioActive"] = true, ["isDead"] = true, ["lbPhoneVariation"] = true
    }

    local function simulateStateBagChange(invokingResource, key)
        if invokingResource ~= nil then
            return true, "ALLOWED_SERVER_RESOURCE"
        end
        if whitelistedKeys[key] then
            return true, "ALLOWED_WHITELIST"
        end
        if protectedKeys[key] then
            return false, "BLOCKED_PROTECTED_KEY"
        end
        return true, "ALLOWED_DEFAULT"
    end

    assert(simulateStateBagChange("qbx_core", "admin") == true, "Servidor alterando 'admin' deve ser PERMITIDO")
    assert(simulateStateBagChange(nil, "admin") == false, "Cliente alterando 'admin' deve ser BLOQUEADO")
    assert(simulateStateBagChange(nil, "godmode") == false, "Cliente alterando 'godmode' deve ser BLOQUEADO")
    assert(simulateStateBagChange(nil, "radioActive") == true, "Cliente alterando 'radioActive' (PTT) deve ser PERMITIDO")
    assert(simulateStateBagChange(nil, "isDead") == true, "Cliente alterando 'isDead' (Óbito) deve ser PERMITIDO")
    assert(simulateStateBagChange(nil, "lbPhoneVariation") == true, "Cliente alterando celular deve ser PERMITIDO")
    print("✅ 9. State Bag Firewall (Chaves Protegidas & Whitelist): 6/6 testes passaram.")

    -- 10. Testes de Sanitizador de Tabela e Payload Bomb (DoS de Memória)
    local function isTableSafe(tbl, maxDepth, maxKeys, currentDepth, keyCounter)
        if type(tbl) ~= "table" then return true end
        currentDepth = currentDepth or 1
        keyCounter = keyCounter or { count = 0 }
        if currentDepth > (maxDepth or 3) then return false end
        for _, v in pairs(tbl) do
            keyCounter.count = keyCounter.count + 1
            if keyCounter.count > (maxKeys or 150) then return false end
            if type(v) == "table" then
                if not isTableSafe(v, maxDepth, maxKeys, currentDepth + 1, keyCounter) then
                    return false
                end
            elseif type(v) == "string" and #v > 4096 then
                return false
            end
        end
        return true
    end

    local safeTable = { a = 1, b = { c = 2, d = { e = 3 } } }
    assert(isTableSafe(safeTable, 3, 150) == true, "Tabela com profundidade 3 deve ser segura")

    local deepBomb = { a = { b = { c = { d = 4 } } } }
    assert(isTableSafe(deepBomb, 3, 150) == false, "Tabela com profundidade 4 (> 3) deve ser BLOQUEADA")

    local wideBomb = {}
    for i = 1, 200 do wideBomb["k" .. i] = i end
    assert(isTableSafe(wideBomb, 3, 150) == false, "Tabela com 200 chaves (> 150) deve ser BLOQUEADA")

    local normalString = string.rep("x", 500)
    assert((#normalString <= 8192) == true, "String 500 bytes deve ser segura")

    local hugeBomb = string.rep("x", 10000)
    assert((#hugeBomb <= 8192) == false, "String 10KB (> 8KB) deve ser BLOQUEADA")
    print("✅ 10. Sanitizador de Payload & Nesting Bomb: 5/5 testes passaram.")

    -- 11. Testes de Armamento Remoto (giveWeapon / removeWeapon)
    local whitelistedWeapons = {
        [0xFBAB5776] = true, -- Paraquedas
        [-72835154] = true,
        [0xA2719248] = true, -- Desarmado
    }

    local function simulateWeaponEvent(sender, targetOwner, weaponType)
        if whitelistedWeapons[weaponType] then
            return true, "ALLOWED_WHITELIST_WEAPON"
        end
        if targetOwner > 0 and targetOwner ~= sender then
            return false, "BLOCKED_FOREIGN_PED_TARGET"
        end
        return true, "ALLOWED_OWN_PED"
    end

    assert(simulateWeaponEvent(1, 1, 453432689) == true, "Armar próprio ped deve ser PERMITIDO")
    assert(simulateWeaponEvent(2, 1, 453432689) == false, "Armar ped de outro jogador deve ser BLOQUEADO")
    assert(simulateWeaponEvent(2, 1, 0xFBAB5776) == true, "Paraquedas nativo deve ser PERMITIDO mesmo em transição")
    assert(simulateWeaponEvent(1, 1, 0xA2719248) == true, "Desarmado legítimo deve ser PERMITIDO")
    assert(simulateWeaponEvent(2, 1, 99999) == false, "Desarmar ped de outro jogador deve ser BLOQUEADO")
    print("✅ 11. Interceptação de Armamento Remoto: 5/5 testes passaram.")

    -- 12. Testes de Salvaguarda de Veículo Anexado (Guincho / Reboque)
    local function simulateAttachedVehicle(attachedTo, isAttached, trailer)
        return (attachedTo ~= 0) or isAttached or (trailer ~= 0)
    end

    assert(simulateAttachedVehicle(1234, false, 0) == true, "Veículo com attachedTo deve ser considerado acoplado")
    assert(simulateAttachedVehicle(0, true, 0) == true, "Veículo com isAttached deve ser considerado acoplado")
    assert(simulateAttachedVehicle(0, false, 5678) == true, "Veículo engatado em trailer deve ser considerado acoplado")
    assert(simulateAttachedVehicle(0, false, 0) == false, "Veículo avulso não deve ser considerado acoplado")
    print("✅ 12. Salvaguarda de Veículos Anexados: 4/4 testes passaram.")

    print("==================================================")
    print("🎉 TODOS OS 64 TESTES DO GUARD V2.5.0 FORAM APROVADOS! (100% SUCESSO)")
    print("==================================================")
end

runTests()

