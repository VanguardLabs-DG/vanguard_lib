-- =========================================================================
-- VANGUARD LIBRARY v2.5.0 | server/guard_config.lua
-- Configuração Declarativa do OneSync Engine Guard & Crash Shield
-- =========================================================================

VanguardGuardConfig = {
    -- Habilita globalmente os interceptadores do motor OneSync
    enabled = true,

    -- Ações em caso de exploit determinístico de crash (quiet-uniform-jersey, october-hotel-echo, etc.)
    -- cancelOnly = false: descarta o pacote e desconecta o jogador com motivo técnico
    kickOnCrashExploit = true,
    kickReason = "Vanguard Guard: Desconectado por anomalia de sincronização de rede OneSync.",

    -- Limites de taxa de criação por segundo (Anti eight-nuts-august / spam de streaming)
    rateLimits = {
        windowSeconds = 5,
        objectsPerSecond = 70,
        vehiclesPerSecond = 10,
        pedsPerSecond = 15,
        explosionsPerWindow = 4,
        particlesPerWindow = 12,
        projectilesPerWindow = 8,
    },

    -- Sanitização Matemática (Anti Havok / RAGE Engine Crash)
    sanitization = {
        minPtFxScale = 0.001,
        maxPtFxScale = 5.0,
        maxProjectileSpeed = 450.0,
        maxExplosionShake = 3.0,
        maxExplosionDamage = 5.0,
        maxWeaponDamage = 65535,
        worldBounds = {
            minX = -8192.0, maxX = 8192.0,
            minY = -8192.0, maxY = 8192.0,
            minZ = -1000.0, maxZ = 5000.0
        }
    },

    -- 1. FIREWALL DE STATE BAGS & ANTI-PAYLOAD BOMB (OneSync Infinity)
    stateBagFirewall = {
        enabled = true,
        maxPayloadBytes = 8192,  -- 8 KB por payload de string
        maxTableDepth = 3,       -- Máximo 3 níveis de aninhamento
        maxTableKeys = 150,      -- Máximo 150 chaves agregadas

        -- Chaves de autoridade estrita do servidor (Cliente NUNCA pode replicar)
        protectedKeys = {
            ["admin"] = true,
            ["staff"] = true,
            ["group"] = true,
            ["job"] = true,
            ["gang"] = true,
            ["duty"] = true,
            ["money"] = true,
            ["bank"] = true,
            ["crypto"] = true,
            ["license"] = true,
            ["cid"] = true,
            ["persisted"] = true,
            ["godmode"] = true,
            ["invisible"] = true,
            ["noclip"] = true,
            ["superjump"] = true,
        },

        -- Whitelist de chaves operacionais ativas na base (Imunidade total a falso positivo)
        whitelistedKeys = {
            ["radioActive"] = true,
            ["disableRadio"] = true,
            ["proximity"] = true,
            ["voiceIntent"] = true,
            ["volumeType"] = true,
            ["isDead"] = true,
            ["dead"] = true,
            ["inBed"] = true,
            ["onStretcher"] = true,
            ["injuries"] = true,
            ["isHandcuffed"] = true,
            ["isEscorted"] = true,
            ["invBusy"] = true,
            ["inv_busy"] = true,
            ["seatbelt"] = true,
            ["stance"] = true,
            ["ptfx"] = true,
            ["lbPhoneVariation"] = true,
            ["phoneLandscape"] = true,
            ["vehicleKeys"] = true,
            ["fuel"] = true,
            ["ox_lib:setVehicleProperties"] = true,
            ["nitroFlames"] = true,
            ["muteBackfire"] = true,
            ["onlyFire"] = true,
        }
    },

    -- 2. INTERCEPTAÇÃO DE EVENTOS DE ARMAMENTO (OneSync C++)
    weaponEvents = {
        enabled = true,
        disallowForeignPedTargeting = true,

        -- Hashes nativos legítimos gerados pelo motor (GTA V engine events)
        whitelistedWeaponHashes = {
            [0xFBAB5776] = true,   -- GADGET_PARACHUTE
            [-72835154] = true,    -- GADGET_PARACHUTE (signed)
            [0xA2719248] = true,   -- WEAPON_UNARMED
            [-1569615261] = true,  -- WEAPON_UNARMED (signed)
            [0x060EC506] = true,   -- WEAPON_FIREEXTINGUISHER
            [101631238] = true,    -- WEAPON_FIREEXTINGUISHER (signed)
            [0x67871003] = true,   -- WEAPON_NIGHTSTICK
            [1737195971] = true,   -- WEAPON_NIGHTSTICK (signed)
        }
    },

    -- 3. SALVAGUARDAS DE VEÍCULOS & REBOQUES (Guinchos & Carretas)
    vehicleSafety = {
        exemptAttachedVehicles = true, -- Isenta veículos em pranchas Flatbed ou anexados
        migrationGracePeriodMs = 3500,  -- Tolerância em transições de motorista/assentos
    },

    -- Lista de modelos de props destrutivos conhecidos por forçar crash de streaming de colisão
    blacklistedEntityModels = {
        "prop_air_bigradar",
        "p_spinning_anus_s",
        "prop_beach_fire",
        "ch3_12_flamethrower",
        "w_pi_flaregun_shell",
        "prop_c4_final_green",
        "c4_final_green",
        "prop_rock_1_a",
        "prop_gold_cont_01"
    },

    -- Tipos de explosão bloqueados por padrão (exceto se acionados por scripts de assalto confiáveis)
    blacklistedExplosionTypes = {
        -- 32 = EXPLOSION_PLANE_ROCKET (se não estiver em aeronave autorizada)
        -- 29 = EXPLOSION_TRAIN
    },

    -- Hashes de partículas comprovadamente abusadas para derrubar FPS ou dereferenciar memória
    blacklistedPtFxHashes = {
        -- Adicione hashes de partículas destrutivas específicas se necessário
    }
}

