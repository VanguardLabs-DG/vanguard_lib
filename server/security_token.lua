-- =========================================================================
-- VANGUARD LIBRARY v2.x | server/security_token.lua
-- Handshake de Ações Sensíveis por One-Time Token (Anti-Executor)
-- Invalida injeções diretas de eventos via consoles de cheats (Eulen, RedEngine).
-- =========================================================================

local ActiveTokens = {}        -- [tokenString] = { source = number, action = string, expire = number }
local PlayerTokenLimits = {}   -- [source] = { count = number, resetTimer = number }
local SecurityManager = {}

-- Semente secreta gerada com alta entropia na inicialização
local SecretSalt = string.format("%s_%s_%06d",
    os.time(),
    GetGameTimer(),
    math.random(100000, 999999)
)

-- Configurações de segurança
local DEFAULT_TTL_MS = 8000   -- 8 segundos de validade máxima para um token
local MAX_TOKENS_PER_WINDOW = 6 -- Máximo de 6 tokens a cada 2 segundos por jogador
local WINDOW_RESET_MS = 2000

--- Emite um token de uso único (Nonce) vinculado a um jogador e a uma ação sensível
--- @param source number | string Server ID
--- @param actionName string Identificador da ação (ex: "concessionaria:comprar")
--- @param ttlMs? number Tempo de vida útil em milissegundos
--- @return string | nil token
function SecurityManager.issueToken(source, actionName, ttlMs)
    local src = tonumber(source)
    if not src or src <= 0 or not actionName or actionName == "" then
        return nil
    end

    local now = GetGameTimer()
    ttlMs = ttlMs or DEFAULT_TTL_MS

    -- 1. Anti-Flooding de solicitação de tokens
    local lim = PlayerTokenLimits[src]
    if not lim or now >= lim.resetTimer then
        PlayerTokenLimits[src] = { count = 1, resetTimer = now + WINDOW_RESET_MS }
    else
        lim.count = lim.count + 1
        if lim.count > MAX_TOKENS_PER_WINDOW then
            print(string.format("^3[Vanguard Security] Jogador [%s] excedeu taxa de solicitação de tokens de segurança.^0", tostring(src)))
            return nil
        end
    end

    -- 2. Geração de token pseudo-aleatório com entropia tripla e semente de execução
    local rand1 = math.random(0, 0x7fffffff)
    local rand2 = math.random(0, 0x7fffffff)
    local token = string.format("vsec_%s_%08x%08x%04x", SecretSalt:sub(1, 8), rand1, rand2, (src * 31) % 65536)

    -- 3. Registro do token em memória
    ActiveTokens[token] = {
        source = src,
        action = actionName,
        expire = now + ttlMs
    }

    return token
end

--- Valida e consome imediatamente (Single-Use) um token de segurança
--- @param source number | string Server ID
--- @param actionName string Nome da ação/evento esperado
--- @param token string Token recebido
--- @return boolean isValid
function SecurityManager.validateToken(source, actionName, token)
    local src = tonumber(source)
    if not src or src <= 0 or not token or type(token) ~= "string" or token == "" then
        return false
    end

    local entry = ActiveTokens[token]
    if not entry then
        return false -- Token inexistente ou já consumido (prevenção de replay)
    end

    -- Consome o token imediatamente para garantir uso estritamente único
    ActiveTokens[token] = nil

    local now = GetGameTimer()

    -- Validação de expiração
    if now > entry.expire then
        return false
    end

    -- Validação de posse (o token deve pertencer ao mesmo jogador)
    if entry.source ~= src then
        return false
    end

    -- Validação do escopo da ação
    if entry.action ~= actionName then
        return false
    end

    return true
end

-- =========================================================================
-- CALLBACKS & LIMPEZA DE MEMÓRIA
-- =========================================================================

-- Callback para o cliente solicitar um token antes de disparar uma ação sensível
if lib and lib.callback then
    lib.callback.register("vanguard:security:requestToken", function(source, actionName)
        return SecurityManager.issueToken(source, actionName)
    end)
end

-- Limpeza de tokens na desconexão (trata coerção de tipo string/number no FiveM)
AddEventHandler("playerDropped", function()
    local src = source
    local numSrc = tonumber(src)
    local strSrc = tostring(src)

    PlayerTokenLimits[src] = nil
    if numSrc then
        PlayerTokenLimits[numSrc] = nil
    end

    for tok, data in pairs(ActiveTokens) do
        if data.source == src or (numSrc and data.source == numSrc) or tostring(data.source) == strSrc then
            ActiveTokens[tok] = nil
        end
    end
end)

-- Thread periódica de Garbage Collection para tokens expirados (roda a cada 30 segundos)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000)
        local now = GetGameTimer()
        for tok, data in pairs(ActiveTokens) do
            if now > data.expire then
                ActiveTokens[tok] = nil
            end
        end
    end
end)

-- =========================================================================
-- EXPORTS
-- =========================================================================

exports('IssueSecurityToken', function(source, actionName, ttlMs)
    return SecurityManager.issueToken(source, actionName, ttlMs)
end)

exports('ValidateSecurityToken', function(source, actionName, token)
    return SecurityManager.validateToken(source, actionName, token)
end)

VanguardSecurity = SecurityManager

print("^5[Vanguard] Lib: Security Token Manager (Anti-Executor) loaded.^0")
