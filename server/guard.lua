-- =========================================================================
-- VANGUARD LIBRARY v2.5.0 | server/guard.lua
-- OneSync Engine Guard & Crash Shield (Firewall de Rede OneSync Infinity)
-- Proteção autônoma nativa contra exploits determinísticos de crash e DoS.
-- =========================================================================

local C = VanguardGuardConfig or {}
if C.enabled == false then
    print("^3[Vanguard Guard] OneSync Engine Guard desativado via configuração.^0")
    return
end

local Guard = {
    buckets = {}, -- [source] = { [kind] = { at = number, n = number } }
    alertCooldowns = {}, -- [source] = { [kind] = number }
    entityBlacklist = {},
    explosionBlacklist = {},
    ptfxBlacklist = {}
}

-- =========================================================================
-- 1. SANITIZADORES MATEMÁTICOS & FÍSICOS (Anti Havok / RAGE Engine Crash)
-- =========================================================================

local function isFiniteNumber(v)
    local n = tonumber(v)
    return n ~= nil and n == n and math.abs(n) ~= math.huge
end

local function isValidCoord(x, y, z)
    if not isFiniteNumber(x) or not isFiniteNumber(y) or not isFiniteNumber(z) then
        return false
    end
    local b = C.sanitization and C.sanitization.worldBounds or {
        minX = -8192.0, maxX = 8192.0,
        minY = -8192.0, maxY = 8192.0,
        minZ = -1000.0, maxZ = 5000.0
    }
    if x < b.minX or x > b.maxX then return false end
    if y < b.minY or y > b.maxY then return false end
    if z < b.minZ or z > b.maxZ then return false end
    return true
end

local function isValidScale(scale, minScale, maxScale)
    if not isFiniteNumber(scale) then return false end
    minScale = minScale or 0.001
    maxScale = maxScale or 5.0
    return scale >= minScale and scale <= maxScale
end

local function isValidVelocity(vx, vy, vz, maxSpeed)
    if not isFiniteNumber(vx) or not isFiniteNumber(vy) or not isFiniteNumber(vz) then
        return false
    end
    maxSpeed = maxSpeed or 450.0
    local speedSq = vx * vx + vy * vy + vz * vz
    return speedSq <= (maxSpeed * maxSpeed)
end

local function isTableSafe(tbl, maxDepth, maxKeys, currentDepth, keyCounter)
    if type(tbl) ~= "table" then return true end
    currentDepth = currentDepth or 1
    keyCounter = keyCounter or { count = 0 }

    if currentDepth > (maxDepth or 3) then
        return false
    end

    for _, v in pairs(tbl) do
        keyCounter.count = keyCounter.count + 1
        if keyCounter.count > (maxKeys or 150) then
            return false
        end

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

local function isVehicleAttachedOrTowed(entity)
    if not entity or entity == 0 then return false end
    if DoesEntityExist and not DoesEntityExist(entity) then return false end

    if GetEntityAttachedTo and GetEntityAttachedTo(entity) ~= 0 then
        return true
    end
    if IsEntityAttached and IsEntityAttached(entity) then
        return true
    end
    if GetVehicleTrailerVehicle and GetVehicleTrailerVehicle(entity) ~= 0 then
        return true
    end
    return false
end


local function makeHashSet(values)
    local set = {}
    for _, v in ipairs(values or {}) do
        local tv = tonumber(v)
        local h = tv or GetHashKey(tostring(v))
        set[h] = true
        if h < 0 then
            set[h + 4294967296] = true
        elseif h > 2147483647 then
            set[h - 4294967296] = true
        end
    end
    return set
end

local function refreshBlacklists()
    Guard.entityBlacklist = makeHashSet(C.blacklistedEntityModels)
    Guard.ptfxBlacklist = makeHashSet(C.blacklistedPtFxHashes)
    Guard.explosionBlacklist = {}
    for _, v in ipairs(C.blacklistedExplosionTypes or {}) do
        local n = tonumber(v)
        if n then Guard.explosionBlacklist[n] = true end
    end
end
refreshBlacklists()

-- =========================================================================
-- 2. RATE LIMITER & AUDITORIA DE SEGURANÇA
-- =========================================================================

local function isStaff(src)
    if not src or src <= 0 then return false end
    if exports.vanguard_lib and exports.vanguard_lib.CheckIfAdmin then
        return exports.vanguard_lib:CheckIfAdmin(src)
    end
    return false
end

local function countWindow(s, kind, limit, windowSec)
    local srcKey = tonumber(s)
    if not srcKey then return false, 0 end

    Guard.buckets[srcKey] = Guard.buckets[srcKey] or {}
    local b = Guard.buckets[srcKey][kind]
    local now = GetGameTimer()
    local windowMs = (windowSec or 5) * 1000

    if not b or (now - b.at) >= windowMs then
        b = { at = now, n = 0 }
        Guard.buckets[srcKey][kind] = b
    end

    b.n = b.n + 1
    return b.n > limit, b.n
end

local function reportIncident(src, violationType, signature, details, shouldDrop)
    local now = GetGameTimer()
    src = tonumber(src)
    if not src or isStaff(src) then return end

    Guard.alertCooldowns[src] = Guard.alertCooldowns[src] or {}
    local lastAlert = Guard.alertCooldowns[src][violationType] or 0

    -- Throttle de alerta por tipo a cada 5 segundos para não saturar
    if (now - lastAlert) >= 5000 then
        Guard.alertCooldowns[src][violationType] = now

        local playerName = GetPlayerName(src) or "Desconhecido"
        local ids = exports.vanguard_lib and exports.vanguard_lib.ExtractIdentifiers and exports.vanguard_lib:ExtractIdentifiers(src) or {}

        print(string.format("^1[Vanguard Guard] VIOLAÇÃO: [%s] '%s' | Assinatura: %s | Tipo: %s^0",
            tostring(src), playerName, tostring(signature), tostring(violationType)))

        if exports.vanguard_lib and exports.vanguard_lib.DiscordLog then
            exports.vanguard_lib:DiscordLog({
                channel = "anticheat",
                priority = "urgent",
                embed = {
                    title = "🛡️ Vanguard Guard • Interceptação de Exploit OneSync",
                    description = string.format("O motor C++ descartou um pacote malformado com assinatura de crash.\n**Ação:** Pacote cancelado (`CancelEvent`)."),
                    color = 0xef4444,
                    fields = {
                        { name = "Jogador", value = string.format("**%s** (ID: `%d`)", playerName, src), inline = true },
                        { name = "Exploit / Assinatura", value = string.format("`%s`", tostring(signature)), inline = true },
                        { name = "Tipo de Evento", value = tostring(violationType), inline = true },
                        { name = "Discord / License", value = string.format("%s | `%s`", ids.discord ~= "" and ids.discord or "N/A", ids.license or "N/A"), inline = false },
                        { name = "Detalhes Técnicos", value = string.format("```json\n%s\n```", json.encode(details or {})), inline = false }
                    }
                }
            })
        end
    end

    if shouldDrop and C.kickOnCrashExploit then
        DropPlayer(src, C.kickReason or "Vanguard Guard: Desconectado por envio de pacote malformado do motor.")
    end
end

-- Limpeza de memória na desconexão do jogador
AddEventHandler("playerDropped", function()
    local src = source
    local numSrc = tonumber(src)
    if numSrc then
        Guard.buckets[numSrc] = nil
        Guard.alertCooldowns[numSrc] = nil
    end
    Guard.buckets[src] = nil
    Guard.alertCooldowns[src] = nil
end)

-- Thread de GC para limpar buckets de rate limit inativos a cada 60s
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        local now = GetGameTimer()
        for src, pBuckets in pairs(Guard.buckets) do
            local hasActive = false
            for kind, b in pairs(pBuckets) do
                if (now - b.at) < 15000 then
                    hasActive = true
                else
                    pBuckets[kind] = nil
                end
            end
            if not hasActive then
                Guard.buckets[src] = nil
            end
        end
    end
end)

-- =========================================================================
-- 3. INTERCEPTADORES ONESYNC (As 5 Blindagens do Motor)
-- =========================================================================

--- 1. Interceptação de ClearPedTasks em outros peds (Mitigação de quiet-uniform-jersey +631F8C)
AddEventHandler('clearPedTasksEvent', function(sender, data)
    local s = tonumber(sender)
    if not s or isStaff(s) then return end
    data = type(data) == 'table' and data or {}

    local netId = tonumber(data.pedId) or 0
    if netId <= 0 then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local owner = tonumber(NetworkGetEntityOwner(entity)) or 0
    if owner > 0 and owner ~= s then
        CancelEvent()
        reportIncident(s, "clear_ped_tasks_foreign", "quiet-uniform-jersey (+631F8C)", {
            targetPedNetId = netId,
            targetOwner = owner,
            immediately = data.immediately,
            reason = "Tentativa de forçar limpeza de animações em ped de outro jogador"
        }, true)
    end
end)

--- 2. Interceptação de Criação de Entidades (Mitigação de eight-nuts-august +133165C)
AddEventHandler('entityCreating', function(entity)
    if not DoesEntityExist(entity) then return end
    local owner = tonumber(NetworkGetEntityOwner(entity))
    if not owner or owner <= 0 or isStaff(owner) then return end

    local typ = GetEntityType(entity)
    if typ ~= 1 and typ ~= 2 and typ ~= 3 then return end

    -- Ignora peds de jogadores legítimos
    if typ == 1 and IsPedAPlayer(entity) then return end

    local model = tonumber(GetEntityModel(entity)) or 0

    -- 2.1 Modelo Nulo / Zero (Gera crash em gta-streaming-five.dll)
    if model == 0 then
        CancelEvent()
        return
    end

    -- 2.2 Coordenadas não-finitas ou fora dos limites do mapa
    local coords = GetEntityCoords(entity)
    if coords and not isValidCoord(coords.x, coords.y, coords.z) then
        CancelEvent()
        reportIncident(owner, "entity_invalid_coords", "quiet-uniform-jersey / black-aspen-tango", {
            model = model,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            reason = "Criação de entidade em coordenadas fora do mundo ou não-finitas"
        }, true)
        return
    end

    -- 2.3 Blacklist de Modelos de Crash de Streaming de Colisão
    if Guard.entityBlacklist[model] then
        CancelEvent()
        reportIncident(owner, "entity_blacklisted", "eight-nuts-august (+133165C)", {
            model = model,
            entityType = typ,
            reason = "Tentativa de instanciar modelo proibido da blacklist de crash"
        }, true)
        return
    end

    -- 2.4 Rate-limiting de criação por segundo (Anti-Flood)
    local limits = C.rateLimits or {}
    local limit = (typ == 3 and (limits.objectsPerSecond or 70))
        or (typ == 2 and (limits.vehiclesPerSecond or 10))
        or (limits.pedsPerSecond or 15)

    local exceeded, count = countWindow(owner, "entity_sec_" .. typ, limit, 1)
    if exceeded then
        CancelEvent()
        -- Flood massivo (> 2.5x o limite) aciona kick automático
        local severeThreshold = limit * 2.5
        local shouldKick = count >= severeThreshold
        reportIncident(owner, "entity_rate_limit", "eight-nuts-august (+133165C)", {
            entityType = typ,
            model = model,
            count = count,
            limit = limit
        }, shouldKick)
    end
end)

--- 3. Interceptação de Explosões (Mitigação de october-hotel-echo +8BABCE)
AddEventHandler('explosionEvent', function(sender, data)
    local s = tonumber(sender)
    if not s or isStaff(s) then return end
    data = type(data) == 'table' and data or {}

    local expType = tonumber(data.explosionType) or -1
    local camShake = tonumber(data.cameraShake)
    local dmgScale = tonumber(data.damageScale)
    local posX = tonumber(data.posX)
    local posY = tonumber(data.posY)
    local posZ = tonumber(data.posZ)
    local sConf = C.sanitization or {}

    -- 3.1 Validação de Tipos e Escalas do Motor
    local maxShake = sConf.maxExplosionShake or 3.0
    local maxDamage = sConf.maxExplosionDamage or 5.0

    if expType < 0 or expType > 72
        or (camShake ~= nil and (not isFiniteNumber(camShake) or camShake > maxShake or camShake < 0.0))
        or (dmgScale ~= nil and (not isFiniteNumber(dmgScale) or dmgScale > maxDamage or dmgScale < 0.0)) then
        CancelEvent()
        reportIncident(s, "explosion_malformed", "october-hotel-echo (+8BABCE)", {
            explosionType = expType,
            cameraShake = camShake,
            damageScale = dmgScale,
            reason = "Explosão com parâmetros matemáticos adulterados fora do limite do motor"
        }, true)
        return
    end

    -- 3.2 Coordenadas da Explosão
    if (posX ~= nil or posY ~= nil or posZ ~= nil) and not isValidCoord(posX, posY, posZ) then
        CancelEvent()
        reportIncident(s, "explosion_invalid_coords", "october-hotel-echo (+8BABCE)", {
            coords = { x = posX, y = posY, z = posZ },
            explosionType = expType,
            reason = "Explosão disparada com coordenadas não-finitas"
        }, true)
        return
    end

    -- 3.3 Blacklist de Tipos de Explosão
    if Guard.explosionBlacklist[expType] then
        CancelEvent()
        reportIncident(s, "explosion_blacklist", "october-hotel-echo (+8BABCE)", {
            explosionType = expType,
            reason = "Tipo de explosão proibido em blacklist"
        }, false)
        return
    end

    -- 3.4 Rate Limit de Explosões por Jogador
    local limits = C.rateLimits or {}
    local maxExp = limits.explosionsPerWindow or 4
    local exceeded, count = countWindow(s, "explosions", maxExp, limits.windowSeconds or 5)
    if exceeded then
        CancelEvent()
        reportIncident(s, "explosion_flood", "october-hotel-echo (+8BABCE)", {
            count = count,
            limit = maxExp
        }, count >= (maxExp * 3))
    end
end)

--- 4. Sanitização de Partículas PTFX (Mitigação de october-hotel-echo)
AddEventHandler('ptFxEvent', function(sender, data)
    local s = tonumber(sender)
    if not s or isStaff(s) then return end
    data = type(data) == 'table' and data or {}

    local scale = tonumber(data.scale)
    local effectHash = tonumber(data.effectHash) or 0
    local posX = tonumber(data.posX or data.positionX)
    local posY = tonumber(data.posY or data.positionY)
    local posZ = tonumber(data.posZ or data.positionZ)
    local sConf = C.sanitization or {}

    -- 4.1 Validação de Escala Exorbitante
    if scale ~= nil and not isValidScale(scale, sConf.minPtFxScale or 0.001, sConf.maxPtFxScale or 5.0) then
        CancelEvent()
        reportIncident(s, "ptfx_invalid_scale", "october-hotel-echo (+8BABCE)", {
            scale = scale,
            effectHash = effectHash,
            reason = "Escala de partícula exorbitante para congelamento de GPU/CPU"
        }, true)
        return
    end

    -- 4.2 Coordenadas
    if (posX ~= nil or posY ~= nil or posZ ~= nil) and not isValidCoord(posX, posY, posZ) then
        CancelEvent()
        return
    end

    -- 4.3 Blacklist de Partículas
    if Guard.ptfxBlacklist[effectHash] then
        CancelEvent()
        reportIncident(s, "ptfx_blacklisted", "eight-nuts-august (+133165C)", {
            effectHash = effectHash
        }, true)
        return
    end

    -- 4.4 Rate Limit de Partículas
    local limits = C.rateLimits or {}
    local maxPtfx = limits.particlesPerWindow or 12
    local exceeded, count = countWindow(s, "ptfx", maxPtfx, limits.windowSeconds or 5)
    if exceeded then
        CancelEvent()
        reportIncident(s, "ptfx_flood", "october-hotel-echo (+8BABCE)", {
            count = count,
            limit = maxPtfx
        }, count >= (maxPtfx * 2))
    end
end)

--- 5. Sanitização de Projéteis & Overflow de Dano (Mitigação de black-aspen-tango +86601B)
AddEventHandler('startProjectileEvent', function(sender, data)
    local s = tonumber(sender)
    if not s or isStaff(s) then return end
    data = type(data) == 'table' and data or {}

    local vel = data.initialVelocity or data.velocity
    if type(vel) == 'vector3' or type(vel) == 'table' then
        local vx = tonumber(vel.x or vel[1])
        local vy = tonumber(vel.y or vel[2])
        local vz = tonumber(vel.z or vel[3])
        local maxSpeed = C.sanitization and C.sanitization.maxProjectileSpeed or 450.0

        if not isValidVelocity(vx, vy, vz, maxSpeed) then
            CancelEvent()
            reportIncident(s, "projectile_invalid_velocity", "black-aspen-tango (+86601B)", {
                velocity = { x = vx, y = vy, z = vz },
                maxSpeed = maxSpeed,
                reason = "Velocidade de projétil anômala/infinita"
            }, true)
            return
        end
    end

    local limits = C.rateLimits or {}
    local maxProj = limits.projectilesPerWindow or 8
    local exceeded, count = countWindow(s, "projectiles", maxProj, limits.windowSeconds or 5)
    if exceeded then
        CancelEvent()
        reportIncident(s, "projectile_flood", "black-aspen-tango (+86601B)", {
            count = count,
            limit = maxProj
        }, count >= (maxProj * 2))
    end
end)

AddEventHandler('weaponDamageEvent', function(sender, data)
    local s = tonumber(sender)
    if not s or type(data) ~= 'table' or isStaff(s) then return end

    -- 5.1 Tipo de Arma Nulo / Não-Finito (Mitigação de dereferência de ponteiro nulo em áudio/decal)
    local weapon = tonumber(data.weaponType)
    if not weapon or weapon == 0 or not isFiniteNumber(weapon) then
        CancelEvent()
        reportIncident(s, "weapon_null_type", "black-aspen-tango (+86601B)", {
            weaponType = tostring(data.weaponType),
            reason = "weaponType nulo ou não-finito (dereferência de nullptr)"
        }, true)
        return
    end

    -- 5.2 Overflow de Dano de Arma (> 65535)
    local damage = tonumber(data.weaponDamage)
    local maxDmg = C.sanitization and C.sanitization.maxWeaponDamage or 65535
    if damage and (not isFiniteNumber(damage) or damage > maxDmg) then
        CancelEvent()
        reportIncident(s, "weapon_damage_overflow", "black-aspen-tango (+86601B)", {
            weaponType = weapon,
            weaponDamage = damage,
            maxDamage = maxDmg,
            reason = "Dano de arma com valor de overflow adulterado"
        }, true)
        return
    end
end)

--- 6. Interceptação de State Bags (Firewall & Anti-Payload Bomb)
if C.stateBagFirewall and C.stateBagFirewall.enabled ~= false then
    local sbConf = C.stateBagFirewall
    local protectedKeys = sbConf.protectedKeys or {}
    local whitelistedKeys = sbConf.whitelistedKeys or {}
    local maxPayload = sbConf.maxPayloadBytes or 8192
    local maxDepth = sbConf.maxTableDepth or 3
    local maxKeys = sbConf.maxTableKeys or 150

    AddStateBagChangeHandler(nil, nil, function(bagName, key, value, _reserved, replicated)
        -- 1. Se foi disparado por recurso legítimo do servidor, permite 100%
        local invoker = GetInvokingResource()
        if invoker ~= nil then
            return
        end

        -- 2. Se a chave estiver explicitamente na whitelist de gameplay da base, permite
        if whitelistedKeys[key] then
            return
        end

        -- 3. Identifica a origem do jogador
        local playerSrc = GetPlayerFromStateBagName and GetPlayerFromStateBagName(bagName) or 0
        if playerSrc and playerSrc > 0 and isStaff(playerSrc) then
            return
        end

        -- 4. Bloqueio de Chaves Protegidas de Autoridade Exclusiva do Servidor
        if protectedKeys[key] then
            CancelEvent()
            if playerSrc and playerSrc > 0 then
                reportIncident(playerSrc, "state_bag_protected_key", "OneSync StateBag Tampering", {
                    key = key,
                    bagName = bagName,
                    valueType = type(value),
                    reason = "Tentativa de injetar StateBag protegido exclusivo do servidor a partir do cliente"
                }, false)
            end
            return
        end

        -- 5. Sanitização de Payload Bomb (DoS de Memória / JSON Bomb)
        if type(value) == "string" then
            if #value > maxPayload then
                CancelEvent()
                if playerSrc and playerSrc > 0 then
                    reportIncident(playerSrc, "state_bag_payload_overflow", "OneSync StateBag DoS Bomb", {
                        key = key,
                        size = #value,
                        maxAllowed = maxPayload,
                        reason = "Payload de StateBag excedeu o limite máximo seguro (8KB)"
                    }, true)
                end
                return
            end
        elseif type(value) == "table" then
            if not isTableSafe(value, maxDepth, maxKeys) then
                CancelEvent()
                if playerSrc and playerSrc > 0 then
                    reportIncident(playerSrc, "state_bag_nesting_bomb", "OneSync StateBag Nesting Bomb", {
                        key = key,
                        reason = "Tabela de StateBag excedeu profundidade máxima ou volume de chaves"
                    }, true)
                end
                return
            end
        end
    end)
end

--- 7. Interceptadores de Armamento Remoto (OneSync C++)
if C.weaponEvents and C.weaponEvents.enabled ~= false then
    local wConf = C.weaponEvents
    local whitelistedWeapons = wConf.whitelistedWeaponHashes or {}

    -- 7.1 giveWeaponEvent
    AddEventHandler('giveWeaponEvent', function(sender, data)
        local s = tonumber(sender)
        if not s or isStaff(s) then return end
        data = type(data) == 'table' and data or {}

        local pedNetId = tonumber(data.pedId) or 0
        if pedNetId <= 0 then return end

        local ped = NetworkGetEntityFromNetworkId(pedNetId)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end

        local weaponType = tonumber(data.weaponType) or 0

        -- Isenção para hashes nativos legítimos (paraquedas, extintor, desarmado, cassetete)
        if whitelistedWeapons[weaponType] then
            return
        end

        local owner = tonumber(NetworkGetEntityOwner(ped)) or 0

        -- Defesa Crítica: Injeção de arma em ped cujo dono na rede é outro jogador
        if owner > 0 and owner ~= s then
            CancelEvent()
            reportIncident(s, "give_weapon_foreign_ped", "OneSync Remote Weapon Injection", {
                targetPedNetId = pedNetId,
                targetOwner = owner,
                weaponType = weaponType,
                ammo = data.ammo,
                reason = "Tentativa de forçar concessão de arma em ped de outro jogador"
            }, true)

            -- RPC silencioso no servidor para garantir desarmamento
            pcall(function()
                RemoveWeaponFromPed(ped, weaponType)
            end)
            return
        end
    end)

    -- 7.2 removeWeaponEvent
    AddEventHandler('removeWeaponEvent', function(sender, data)
        local s = tonumber(sender)
        if not s or isStaff(s) then return end
        data = type(data) == 'table' and data or {}

        local pedNetId = tonumber(data.pedId) or 0
        if pedNetId <= 0 then return end

        local ped = NetworkGetEntityFromNetworkId(pedNetId)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end

        local owner = tonumber(NetworkGetEntityOwner(ped)) or 0

        -- Defesa Crítica: Desarmamento de ped alheio (desarme remoto em tiroteio)
        if owner > 0 and owner ~= s then
            CancelEvent()
            reportIncident(s, "remove_weapon_foreign_ped", "OneSync Remote Weapon Disarm", {
                targetPedNetId = pedNetId,
                targetOwner = owner,
                weaponType = data.weaponType,
                reason = "Tentativa de desarmar remotamente ped de outro jogador"
            }, true)
            return
        end
    end)

    -- 7.3 removeAllWeaponsEvent
    AddEventHandler('removeAllWeaponsEvent', function(sender, data)
        local s = tonumber(sender)
        if not s or isStaff(s) then return end
        data = type(data) == 'table' and data or {}

        local pedNetId = tonumber(data.pedId) or 0
        if pedNetId <= 0 then return end

        local ped = NetworkGetEntityFromNetworkId(pedNetId)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end

        local owner = tonumber(NetworkGetEntityOwner(ped)) or 0

        -- Defesa Crítica: Remoção total de armas de ped alheio
        if owner > 0 and owner ~= s then
            CancelEvent()
            reportIncident(s, "remove_all_weapons_foreign_ped", "OneSync Remote Mass Disarm", {
                targetPedNetId = pedNetId,
                targetOwner = owner,
                reason = "Tentativa de limpar todas as armas de ped de outro jogador"
            }, true)
            return
        end
    end)
end

-- =========================================================================
-- 4. EXPORTS & CONTROLE PROGRAMÁTICO
-- =========================================================================

exports('GuardIsStaff', function(src)
    return isStaff(src)
end)

exports('GuardRefreshBlacklists', function()
    refreshBlacklists()
    return true
end)

exports('GuardIsTableSafe', function(tbl, maxDepth, maxKeys)
    return isTableSafe(tbl, maxDepth, maxKeys)
end)

exports('GuardIsVehicleAttached', function(entity)
    return isVehicleAttachedOrTowed(entity)
end)

VanguardGuard = Guard

print("^5[Vanguard] Lib: OneSync Engine Guard & Crash Shield v2.5.0 loaded.^0")
