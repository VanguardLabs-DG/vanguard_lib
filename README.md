# 🛡️ Vanguard Library (vanguard_lib) v2.5.0

> **Shared Core, Application Framework, Microfrontend Engine & OneSync Crash Shield for FiveM**  
> Desenvolvido para o ecossistema **Distrito Paulista**, integrando **QBX Core**, **ox_lib**, **ox_inventory** e **vanguard_esc**.

---

## 📌 Visão Geral

O **`vanguard_lib`** é uma biblioteca de alto desempenho projetada para resolver a fragmentação de código, duplicidade de assets, vulnerabilidades de concorrência e exploits de crash em servidores FiveM. 

Enquanto a `ox_lib` provê primitivas genéricas de motor (pontos, zonas, raycasting, cache), o `vanguard_lib` atua como a **Camada de Aplicação, Negócio e Defesa do Motor OneSync**:
- 🛡️ **OneSync Engine Guard & Crash Shield (Zero-Config):** Interceptação C++ server-side nativa contra exploits determinísticos de crash em massa (`quiet-uniform-jersey`, `eight-nuts-august`, `october-hotel-echo`, `black-aspen-tango`) e rate limiting de entidades/explosões sem falsos positivos.
- ⚡ **Zero-Latency Module:** Importação direta via `@vanguard_lib/init.lua` sem overhead de chamadas `exports`.
- 🔐 **Handshake Anti-Executor por One-Time Token:** Invalida 100% de injeções de eventos por DLLs externas exigindo nonces descartáveis gerados pela NUI.
- 🔄 **Transações Atômicas com Rollback (ACID FiveM):** Padrão Saga com compensação reversa LIFO para dinheiro, inventário e MySQL sem perdas ou duplicações.
- 📨 **Fila em Lote de Webhooks (Anti-429):** Compactador de até 10 embeds por request com filas de prioridade e backoff inteligente.
- 🛡️ **Middleware Declarativo de Eventos:** Rate limiting, type safety, anti-spoofing e validação de tokens automáticos para NetEvents.
- 🎨 **SDK de Microfrontends (NUI):** Iframe bridge padronizada com *Deep Sleep Protocol* (`.cef-dormant`), prevenção de keyboard traps e comunicação reativa com o `vanguard_esc`.
- 🎒 **Inventário Unificado:** Wrappers padronizados para `ox_inventory` e QBX Core com validações automáticas de capacidade de carga.
- 🌐 **CDN Local Offline (0ms Latency):** Alpine.js, FontAwesome e fontes servidos localmente via NUI sem depender de conexão externa à internet.
- 💰 **Economia Segura & Auditoria:** Wrappers blindados contra exploits de NaN/Infinity com rastreabilidade obrigatória de transações (`reason`).
- 🗺️ **Engine Gráfica & Atlas:** Renderizador WebGL (Three.js) e tilesets de satélite para mapas NUI de alta fidelidade.

---

## 🏗️ Arquitetura em Camadas

```mermaid
graph TD
    subgraph "Recursos Consumidores (Lojas, Garagens, VIP, Cassino, etc.)"
        UserScript[Script do Servidor]
    end

    subgraph "vanguard_lib (Camada de Negócio, UI, Segurança & Motor)"
        InitLua["@vanguard_lib/init.lua (Zero-Latency API)"]
        EngineGuard["OneSync Engine Guard (Firewall C++ Anti-Crash)"]
        EventMiddleware["Middleware Declarativo (Rate Limit + Type Safety)"]
        PluginBridge["vanguard-plugin-bridge.js (Microfrontends NUI)"]
        VendorAssets["CDN Local (Alpine, FontAwesome, Design Tokens)"]
        RateLimiter["Rate Limiter Centralizado (Anti-Race Condition)"]
        FrameworkFacade["QBX Core Facade & Audit Logging"]
    end

    subgraph "Motor & Infraestrutura Base (FiveM C++ / FXServer)"
        OneSyncEvents["OneSync Infinity Events (entityCreating, clearPedTasksEvent, ptFx, etc.)"]
        OxLib["ox_lib (Zonas, Callbacks, Points, Cache)"]
        QbxCore["qbx_core (Player, Accounts, StateBags)"]
        OxMysql["oxmysql"]
    end

    UserScript -->|Importa| InitLua
    UserScript -->|Usa UIs & Tokens| VendorAssets
    UserScript -->|Embutido no ESC| PluginBridge

    OneSyncEvents -->|Interceptado por| EngineGuard
    InitLua --> EventMiddleware
    InitLua --> FrameworkFacade
    EventMiddleware --> RateLimiter
    FrameworkFacade --> QbxCore
    InitLua --> OxLib
```

---

## 🚀 Instalação & Guia Rápido

### 1. Requisitos
- `ox_lib` (Overextended)
- `qbx_core` (Qbox Project)
- `oxmysql`
- FiveM Server Artifacts `7290+` com `lua54 'yes'`

### 2. Como usar em novos scripts (Recomendado - v2.0)
No `fxmanifest.lua` do seu script:
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@vanguard_lib/init.lua' -- Importa a tabela global vanguard
}
```

Pronto! A tabela global `vanguard` já estará disponível no client e no server com autocomplete e latência zero.

---

## 📜 O Contrato de Engenharia: Blueprint para Scripts Blindados (Dev & LLM Contract)

> **MANDATÓRIO PARA DEVS E IAs (LLMs):**  
> Qualquer desenvolvedor humano ou modelo de IA que for criar, expandir ou refatorar um script no ecossistema **Distrito Paulista** utilizando o `vanguard_lib` **DEVE** seguir este contrato arquitetural. Violar este padrão reintroduz falhas de duplicação por race condition, bloqueios 429 no Discord ou vulnerabilidades a injeção por executores de cheats.

### 🛡️ Os 5 Mandamentos da Arquitetura Vanguard

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 1. IMPORTAÇÃO ZERO-LATÊNCIA   ➜ shared_scripts com @vanguard_lib/init.lua              │
│ 2. HANDSHAKE ANTI-EXECUTOR    ➜ requireToken = true em toda ação sensível da NUI      │
│ 3. TRANSAÇÃO ATÔMICA ACID     ➜ vanguard.transaction.run (Débito ➜ BD ➜ Entrega)       │
│ 4. REATIVIDADE NUI PUB/SUB    ➜ vanguard.state.set no server, $vState/$store no NUI   │
│ 5. LOGS BATCHED SEM 429       ➜ vanguard.discord.log com compactor de 10 embeds        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

#### 1. Manifest com Zero Latência
- **Regra:** Todo script DEVE declarar no `fxmanifest.lua`:
  ```lua
  shared_scripts {
      '@ox_lib/init.lua',
      '@vanguard_lib/init.lua'
  }
  ```
- **Proibido:** NUNCA utilize `exports.vanguard_lib:X` para métodos disponíveis no módulo `vanguard.*`. A tabela global `vanguard` provê execução in-process com zero custo de call inter-resource.

#### 2. Blindagem Anti-Executor em Ações de Interface (`requireToken = true`)
- **Regra:** Se a ação transfere dinheiro, entrega itens, compra veículos ou altera dados persistentes iniciada por um clique do jogador na NUI:
  - **No Frontend NUI (JS):** Dispare usando `await plugin.postSecureNui('actionName', data)` ou solicite o token antes com `await plugin.requestSecureToken('actionName')`.
  - **No Backend (Lua):** Registre o evento estritamente com `vanguard.registerServerEvent(eventName, { requireToken = true, rateLimit = ..., validateArgs = { ... } }, handler)`.
  - **Mecanismo:** Cheaters que tentarem disparar `TriggerServerEvent('loja:comprar', 'arma', 0)` via console externo não possuirão o token temporal assinado emitido pela NUI. A ação é descartada na hora e gera um alerta emergencial no canal `anticheat` do Discord.

#### 3. Transacionalidade Atômica Obrigatória (`vanguard.transaction.run`)
- **Regra:** Operações que envolvem 2 ou mais passos distribuídos (Dinheiro + Inventário, Dinheiro + MySQL, ou Item + MySQL) **NUNCA** devem ser executadas com funções soltas!
- **Ordem Canônica dos Passos:**
  1. **Débito:** `tx:removeMoney()` ou `tx:removeItem()` (garante que o recurso saiu do jogador primeiro).
  2. **Persistência / Mudança de Estado:** `tx:dbInsert()` ou queries SQL no banco.
  3. **Crédito / Entrega:** `tx:addItem()` ou `tx:addMoney()` (entrega a contrapartida).
- **Garantia ACID:** Se o inventário estiver cheio, o peso exceder o limite ou o banco oscilar no meio do caminho, o `vanguard.transaction` executa o **Rollback LIFO** automático, estornando as etapas anteriores na ordem inversa. Zero duplicações e zero tickets de suporte.

#### 4. Reatividade Global de Estado (`vanguard.state`)
- **Regra:** Se uma informação precisa refletir em múltiplos microfrontends da cidade (saldo de gemas, status VIP, dinheiro na carteira, nível de passe), **NUNCA** crie eventos de rede manuais em cadeia para atualizar cada tela.
- **Padrão:**
  - No Servidor: `vanguard.state.set(source, 'user.gems', 500)` ou `vanguard.state.patch(source, { ['user.gems'] = 500, ['vip.tier'] = 'diamond' })`.
  - No Frontend NUI: O estado sincroniza automaticamente em background via NUI Bridge. No Alpine.js, acesse reativamente via `$store.vanguard.user.gems` ou use `this.state.subscribe('user.gems', (newVal) => { ... })`.

#### 5. Logs Resilientes sem 429 (`vanguard.discord.log`)
- **Regra:** NUNCA faça chamadas diretas com `PerformHttpRequest` para webhooks do Discord dentro de eventos de compras, baús ou comandos.
- **Padrão:** Use `vanguard.discord.log({ channel = "financeiro", priority = "normal", embed = { ... } })`.
- O agregador agrupa até 10 embeds por request, possui filas de prioridade (`urgent`, `normal`, `bulk`) e lê o cabeçalho `retry_after`, prevenindo que a staff perca logs de auditoria durante horários de pico.

---

### 💻 Template Canônico de Implementação (Script Blindado de Referência)

Abaixo está o molde padrão de um recurso completo de loja/serviço para o ecossistema Vanguard:

#### 📄 `fxmanifest.lua`
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@vanguard_lib/init.lua' -- Padrão Vanguard v2.x
}

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/**/*' }
```

#### 📄 `server/main.lua` (Backend Blindado)
```lua
-- Registro com Handshake Anti-Executor, Rate Limiting e Validação de Tipos
vanguard.registerServerEvent('dp_loja:comprarItem', {
    requireToken = true,                       -- 1. Anti-Cheat: exige token descartável da NUI
    rateLimit = 1500,                          -- 2. Anti-Macro: cooldown de 1.5s por player
    validateArgs = { 'string', 'number' },     -- 3. Type Safety: nome do item (string), qtd (number)
    requireAuth = true                         -- 4. Anti-Spoof: valida conexão genuína
}, function(source, itemName, count)
    local itemPreco = 1500 * count

    -- 5. Execução em Bloco Transacional ACID com Rollback LIFO
    local success, result, err = vanguard.transaction.run({
        source = source,
        label = "loja_compra:" .. itemName,
        timeout = 6000
    }, function(tx)
        -- Passo 1: Débito com compensação nativa
        tx:removeMoney("bank", itemPreco, "Loja: Compra de " .. itemName)

        -- Passo 2: Entrega de item com validação de peso/ox_inventory e compensação
        tx:addItem(itemName, count)

        -- Passo 3: Auditoria no banco de dados com compensação automática
        tx:dbInsert("INSERT INTO loja_vendas (source, item, count, price) VALUES (?, ?, ?, ?)", 
            { source, itemName, count, itemPreco }, "loja_vendas")

        return { item = itemName, count = count }
    end)

    if not success then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = err.message or 'Falha ao processar compra. Nenhum valor foi cobrado.'
        })
        return
    end

    -- 6. Log Resiliente no Discord (Agrupado com proteção anti-429)
    vanguard.discord.log({
        channel = "financeiro",
        priority = "normal",
        embed = {
            title = "🛒 Compra Concluída",
            description = string.format("Player **%s** comprou **%dx %s** por **R$ %d**", 
                vanguard.player.getName(source), count, itemName, itemPreco),
            color = 0x10b981
        }
    })

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = string.format('Você comprou %dx %s com sucesso!', count, itemName)
    })
end)
```

#### 📄 `web/script.js` (Frontend NUI com Microfrontend SDK)
```javascript
// Instanciação oficial com suporte a State Store e One-Time Tokens
const plugin = new VanguardPlugin({
    id: 'dp_loja',
    onInit: (data) => console.log('Loja inicializada com sucesso')
});

// Ação de compra blindada com One-Time Token automático
async function comprarItem(itemName, count) {
    try {
        // postSecureNui solicita o Nonce descartável ao vanguard_lib e anexa ao payload
        const response = await plugin.postSecureNui('dp_loja:comprarItem', {
            item: itemName,
            amount: Number(count)
        });
        return response;
    } catch (err) {
        console.error('Falha ao despachar requisição segura:', err);
    }
}
```

---

## 📖 Referência da API Lua (`vanguard.*`)

### 1. Middleware Declarativo de Eventos de Rede (Server)
Elimina a necessidade de escrever validações repetitivas dentro de cada evento.

```lua
vanguard.registerServerEvent(eventName, options, handler)
```

#### Opções Suportadas:
| Opção | Tipo | Descrição |
| :--- | :--- | :--- |
| `requireToken` | `boolean` | Se `true`, exige e consome um One-Time Token descartável emitido pela NUI. Invalida 100% de injeções diretas via executores de cheats. |
| `rateLimit` | `number` | Cooldown em milissegundos por jogador para esse evento. Bloqueia autoclickers/spam. |
| `validateArgs` | `table` | Array de tipos esperados (`"string"`, `"number"`, `"table"`, `"boolean"`, `"any"`). Suporta opcionais com prefixo `?` (ex: `"?number"`). |
| `requireAuth` | `boolean` | Se `true` (padrão), descarta eventos de endpoints nulos ou inválidos (anti-spoof). |
| `onSecurityViolation`| `function(src, eventName, token)` | Callback opcional acionado em caso de token inválido ou injeção detectada. |
| `onRateLimited` | `function(src, eventName)` | Callback opcional acionado quando o jogador atinge o cooldown. |
| `onValidationFailed` | `function(src, paramIdx, expected, actual)` | Callback opcional acionado em caso de injeção de tipo incorreto. |

#### Exemplo Prático:
```lua
vanguard.registerServerEvent('concessionaria:comprarCarro', {
    requireToken = true,                              -- Blindagem Anti-Executor!
    rateLimit = 2000,                                 -- 2 segundos de cooldown
    validateArgs = { 'string', 'number', '?string' }, -- modelo, preco, cor (opcional)
    requireAuth = true
}, function(source, modelo, preco, cor)
    -- Se chegou aqui:
    -- 1. O clique originou comprovadamente de dentro da NUI com token descartável único
    -- 2. O player não é fantasma
    -- 3. Não está floodando cliques
    -- 4. Os argumentos têm os tipos corretos
    local removeu = vanguard.player.removeMoney(source, 'bank', preco, 'compra_carro:' .. modelo)
    if removeu then
        -- Entregar veículo
    end
end)
```

---

### 2. Rate Limiting Manual
Ideal para ser usado dentro de loops, comandos ou verificações manuais.

```lua
-- Checa se a ação é permitida (retorna true se permitido, false se em cooldown)
local permitido = vanguard.rateLimit(source, "resgatar_recompensa", 5000)

-- Limpa os cooldowns ativos de um jogador (ex: no logout)
vanguard.clearRateLimit(source)
```

---

### 3. Economia & Dados do Jogador (`vanguard.player.*`)

Todas as funções de dinheiro são protegidas internamente contra `NaN`, `Infinity`, valores negativos e transações de valores zero.

```lua
-- Retorna o objeto Player do QBX Core
local player = vanguard.player.get(source)

-- Saldo bancário ou dinheiro em mãos
local saldoBanco = vanguard.player.getMoney(source, 'bank')
local saldoCash  = vanguard.player.getMoney(source, 'cash')

-- Adicionar dinheiro com justificativa obrigatória para auditoria no Discord
local sucesso = vanguard.player.addMoney(source, 'bank', 500, 'salario_policia')

-- Remover dinheiro com justificativa
local sucesso = vanguard.player.removeMoney(source, 'bank', 250, 'taxa_hospital')

-- Informações do emprego (retorna: name, grade, label, gradename)
local jobName, gradeLevel, jobLabel, gradeName = vanguard.player.getJob(source)

-- Identificadores e Perfil
local citizenId = vanguard.player.getCitizenId(source)
local nomeCompleto = vanguard.player.getName(source)
local isOnline = vanguard.player.isOnline(source)
local isAdmin = vanguard.player.isAdmin(source) -- Suporta QBX HasPermission('admin') e ACE
local ids = vanguard.player.getIdentifiers(source) -- { steam, discord, license }
```

---

### 4. Callbacks Seguros (`vanguard.callback.*`)
Wrapper de alta compatibilidade sobre a `ox_lib` com timeout preventivo de 10s contra coroutine leaks:

```lua
-- NO SERVIDOR:
vanguard.callback.register('meuScript:obterDados', function(source, param1)
    return { status = "ok", saldo = 100 }
end)

-- NO CLIENTE:
local resposta = vanguard.callback.await('meuScript:obterDados', "parametro")
print(resposta.status)
```

---

### 5. Geometria & Proximidade (`vanguard.geo.*` - Client)
```lua
-- Retorna uma tabela de Server IDs dos jogadores num raio de 3.5 unidades
local jogadoresPerto = vanguard.geo.getClosestPlayers()

-- Retorna o nome formatado da rua/bairro de uma coordenada
local bairro = vanguard.geo.getStreetZone(GetEntityCoords(PlayerPedId()))
```

---

### 6. Discord API & Utilitários
```lua
-- Retorna o link do avatar do jogador (com cache inteligente e TTL de 2h)
local avatarUrl = vanguard.discord.getAvatar(source)

-- Gera um UUID v4 (RFC 4122)
local novoId = vanguard.uuid()
```

---

### 7. Gerenciador de Transações Atômicas com Rollback (`vanguard.transaction`)

Elimina a inconsistência de dados (tickets de "perdi dinheiro e não veio o item/carro") e duplicações por race condition executando passos em padrão Saga com reversão reversa (**LIFO**):

```lua
local success, result, err = vanguard.transaction.run({
    source = source,
    label = "loja_armas:comprar",
    timeout = 5000, -- Fail-safe de tempo limite
}, function(tx)
    -- Passo 1: Debitar dinheiro (se falhar ou faltar saldo, aborta)
    tx:removeMoney("bank", 15000, "Compra Carabina")

    -- Passo 2: Entregar item no inventário (se o inventário estiver cheio, estorna o Passo 1!)
    tx:addItem("weapon_carbinerifle", 1, { ammo = 250 })

    -- Passo 3: Inserir log no banco com rollback customizado
    local logId = tx:dbInsert(
        "INSERT INTO player_purchases (citizenid, item, price) VALUES (?, ?, ?)",
        { citizenId, "weapon_carbinerifle", 15000 },
        "player_purchases" -- Tabela para DELETE automático caso um passo futuro falhe
    )

    return { purchaseId = logId }
end)

if not success then
    print(string.format("^3[Transação Abortada] Motivo: %s (Etapa: %s)^0", err.message, err.step))
    -- O dinheiro já foi devolvido automaticamente para a conta do jogador!
end
```

#### Recursos do Contexto `tx`:
- `tx:removeMoney(moneyType, amount, reason)` ➡️ Debita com estorno automático.
- `tx:addMoney(moneyType, amount, reason)` ➡️ Credita com débito compensatório.
- `tx:addItem(item, count, metadata, slot)` ➡️ Valida peso e entrega com remoção compensatória.
- `tx:removeItem(item, count, metadata, slot)` ➡️ Remove com devolução compensatória.
- `tx:dbInsert(query, params, tableNameOrCompensateFn)` ➡️ Inserção com deleção reversa.
- `tx:step({ name, execute, compensate })` ➡️ Passos com compensação arbitrária.
- `tx:fail(reason)` ➡️ Cancela e aciona rollback imediatamente.

---

### 8. Fila em Lote de Webhooks do Discord (Anti-Rate-Limit 429) (`vanguard.discord.log`)

Evita o erro `429 Too Many Requests` e micro-stutters de rede agrupando até **10 embeds** por requisição HTTP, com leitura automática de `retry_after` e buffer circular:

```lua
-- Envio assíncrono com prioridade e agrupamento automático
vanguard.discord.log({
    channel = "financeiro", -- Alias mapeado ou URL direta
    priority = "normal",    -- "urgent" (250ms), "normal" (2s), "bulk" (5s)
    embed = {
        title = "💰 Compra na Concessionária",
        description = string.format("O jogador **%s** adquiriu o veículo **%s**.", nome, modelo),
        color = 0x10b981,
        fields = {
            { name = "Valor", value = "R$ " .. preco, inline = true },
            { name = "Placa", value = placa, inline = true }
        }
    }
})

-- Canais pré-configurados suportados via server.cfg:
-- set vanguard_webhook_general "https://discord.com/api/webhooks/..."
-- set vanguard_webhook_financeiro "https://discord.com/api/webhooks/..."
-- set vanguard_webhook_anticheat "https://discord.com/api/webhooks/..."
-- set vanguard_webhook_admin "https://discord.com/api/webhooks/..."
```

---

### 9. Inventário Unificado (`vanguard.inventory.*`)

Abstração sobre `ox_inventory` e `qbx_core` garantindo operações uniformes:

```lua
-- Checar se o jogador tem espaço/peso para carregar
local podeCarregar = vanguard.inventory.canCarryItem(source, "radio", 1)

-- Adicionar item
local adicionou = vanguard.inventory.addItem(source, "water_bottle", 2)

-- Remover item
local removeu = vanguard.inventory.removeItem(source, "water_bottle", 1)

-- Quantidade de itens
local totalAgua = vanguard.inventory.getItemCount(source, "water_bottle")
```

---

### 10. Reatividade & State Store Global (`vanguard.state`)

Sincroniza dados em tempo real entre o **Server**, o **Client Lua** e todas as janelas/iframes da **NUI** (`vanguard_esc` e plugins):

#### No Servidor (Lua):
```lua
-- Define o saldo de gemas e sincroniza automaticamente a NUI do jogador:
vanguard.state.set(source, 'gems', 1500)

-- Define estado global (transmitido para todos os jogadores online):
vanguard.state.set(0, 'weather.season', 'summer')

-- Obtém estado
local saldoGemas = vanguard.state.get(source, 'gems', 0)
```

#### No Cliente (Lua):
```lua
-- Obtém o valor atual sincronizado
local gemas = vanguard.state.get('gems', 0)

-- Notifica a NUI localmente
vanguard.state.set('gems', 2000)
```

---

### 11. Handshake de Ações Sensíveis por One-Time Token (`vanguard.security`)

Impede que cheaters com executores de DLL externos (Eulen, RedEngine) executem eventos de compra, resgate ou recompensa diretamente pelo console do jogo.

#### Como funciona:
1. No Javascript (NUI), o jogador clica genuinamente em um botão de ação.
2. O Bridge gera ou solicita um token temporário de uso único (Nonce):
   ```javascript
   // Opção 1: Via postSecureNui automático
   const resposta = await plugin.postSecureNui('loja:comprarCarro', { modelo: 'adder', preco: 150000 });

   // Opção 2: Obtendo o token avulso
   const token = await plugin.requestSecureToken('loja:comprarCarro');
   ```
3. O servidor valida o token no middleware declarativo `vanguard.registerServerEvent({ requireToken = true })`:
   - Se o token for válido: consome-o imediatamente (Single-Use, impossibilitando reuso/replay) e executa o handler com parâmetros limpos.
   - Se for injetado sem token ou com token forjado: descarta a ação instantaneamente e despacha alerta de anticheat no Discord!

#### Métodos em Lua:
```lua
-- No Servidor:
local token = vanguard.security.issueToken(source, "eventoAlvo", 8000)
local valido = vanguard.security.validateToken(source, "eventoAlvo", token)

-- No Cliente:
local token = vanguard.security.requestToken("eventoAlvo")
vanguard.security.triggerSecuredServerEvent("eventoAlvo", param1, param2)
```

---

### 12. OneSync Engine Guard & Crash Shield (`vanguard.guard`)

Camada autônoma de firewall de motor FiveM (C++ / OneSync Infinity). **Não requer configuração por scripts consumidores**: ao rodar o `vanguard_lib`, o servidor ganha imunidade imediata contra as principais assinaturas de exploits de crash em massa e manipulações indevidas de rede.

#### Proteções Ativas no Motor:
| Assinatura do Exploit | Evento OneSync | Ação Preventiva |
| :--- | :--- | :--- |
| **`quiet-uniform-jersey (+631F8C)`** | `clearPedTasksEvent` | Descarta tentativas de limpar tarefas em ped de outro jogador (`owner ~= sender`). |
| **`eight-nuts-august (+133165C)`** | `entityCreating` | Bloqueia modelo 0, coordenadas não-finitas/fora do mapa, modelos de colisão destrutivos em blacklist e rate-limit de criação. |
| **`october-hotel-echo (+8BABCE)`** | `explosionEvent` | Sanitiza parâmetros matemáticos (`cameraShake <= 3.0`, `damageScale <= 5.0`), tipos inválidos e flood de explosões. |
| **`october-hotel-echo`** | `ptFxEvent` | Bloqueia escalas exorbitantes de partículas (GPU freeze), hashes de partículas maliciosas e rate-limit. |
| **`black-aspen-tango (+86601B)`** | `startProjectileEvent` / `weaponDamageEvent` | Sanitiza velocidade de projéteis, descarta armas com tipo nulo (dereferência de nullptr) e overflow de dano (> 65535). |
| **`StateBag Tampering & DoS Bomb`** | `AddStateBagChangeHandler` | Bloqueia injeção cliente de chaves exclusivas de servidor (`admin`, `money`, `godmode`) e neutraliza payloads > 8KB ou tabelas com profundidade > 3. |
| **`Remote Weapon Disarm & Injection`** | `giveWeaponEvent` / `removeWeaponEvent` | Bloqueia tentativas de dar ou remover armas em peds cujo dono de rede é outro jogador (`owner ~= sender`), com RPC de strip silencioso. |
| **`Vehicle Tow / Hijack Safeguard`** | `entityCreating` / Network | Reconhece veículos acoplados a guinchos (Flatbeds) e carretas de carga, isentando-os de falhas de ausência de condutor. |

#### Métodos em Lua (Server):
```lua
-- Verifica se o jogador possui imunidade administrativa no Guard
local isImmune = vanguard.guard.isStaff(source)

-- Recarrega as blacklists de modelos, projéteis e explosões em tempo de execução
vanguard.guard.refreshBlacklists()

-- Valida se uma tabela arbitrária é segura contra DoS/Nesting Bombs
local isSafe = vanguard.guard.isTableSafe(tabela, 3, 150)

-- Checa se um veículo está acoplado a guincho, prancha ou reboque
local isAttached = vanguard.guard.isVehicleAttached(entity)
```

---

## 🎨 SDK de Microfrontends (NUI)

O `vanguard_lib` introduz uma arquitetura de **Microfrontends para FiveM**, permitindo que interfaces (como Passe de Batalha, Loja VIP, Painel de Facção, etc.) rodem desacopladas dentro do menu ESC (`vanguard_esc`) através de iframes com reatividade global via Pub/Sub.

### 1. Inclusão dos Assets Offline (Zero Latency)
No seu `index.html`, utilize as tags locais apontando para o `vanguard_lib` em vez de CDNs externas:

```html
<!-- Design Tokens (Cores, Bordas, Deep Sleep) -->
<link rel="stylesheet" href="https://cfx-nui-vanguard_lib/vendor/css/vanguard-tokens.css">

<!-- FontAwesome 6 Pro & Fontes Oficiais -->
<link rel="stylesheet" href="https://cfx-nui-vanguard_lib/vendor/fontawesome/css/all.min.css">
<link rel="stylesheet" href="https://cfx-nui-vanguard_lib/vendor/fonts/fonts.css">

<!-- Alpine.js 3.x Local -->
<script src="https://cfx-nui-vanguard_lib/vendor/alpine/alpine.min.js" defer></script>

<!-- Global State Store Engine & Plugin Bridge SDK -->
<script src="https://cfx-nui-vanguard_lib/js/vanguard-state-store.js"></script>
<script src="https://cfx-nui-vanguard_lib/js/vanguard-plugin-bridge.js"></script>
```

---

### 2. Inicializando o Plugin no Javascript
Crie uma instância do `VanguardPlugin` no seu arquivo JS principal:

```javascript
const plugin = new VanguardPlugin({
    id: 'loja_gemas', // ID único do seu plugin
    allowStandalone: false, // Bloqueia abertura fora do vanguard_esc

    // Chamado quando o menu ESC inicializa o plugin
    onInit: (payload) => {
        console.log("Plugin inicializado com dados:", payload);
    },

    // Chamado quando a aba do plugin ganha ou perde foco
    onVisibility: (visible) => {
        if (visible) {
            // Recarregar dados / atualizar estado
        }
    },

    // Notificação de atualização de saldo de gemas
    onUpdateGems: (totalGemas) => {
        document.getElementById('gemas-count').innerText = totalGemas;
    },

    // Checagem de modais internos para o botão ESC fechar o modal antes de fechar o menu
    isModalOpen: () => {
        return !!document.querySelector('.modal.ativo');
    },
    closeModal: () => {
        document.querySelector('.modal.ativo')?.classList.remove('ativo');
    }
});

// Para enviar requisições NUI para o client.lua do SEU PRÓPRIO script:
async function comprarItem(itemId) {
    const resposta = await plugin.postNui('comprarItem', { id: itemId });
    if (resposta?.sucesso) {
        plugin.state.set('gems', resposta.novasGemas); // Atualiza reativamente o ESC e todos os iframes!
    }
}

// Ouvir alterações reativas de qualquer chave do estado compartilhado:
plugin.state.subscribe('gems', (novasGemas) => {
    document.getElementById('gemas-count').innerText = novasGemas;
});

plugin.state.subscribe('vip.tier', (novoTier) => {
    console.log("VIP atualizado para:", novoTier);
});

// Para fechar o menu ESC a partir do plugin:
function fechar() {
    plugin.close();
}
```

---

### 3. Deep Sleep Protocol (`.cef-dormant`)
Quando o jogador minimiza o menu ou troca de aba, o `vanguard-plugin-bridge.js` adiciona automaticamente a classe CSS `.cef-dormant` na tag `<html>` do seu plugin.

O [vanguard-tokens.css](file:///home/bases/mri_paulista/resources/[vanguard]/vanguard_lib/vendor/css/vanguard-tokens.css) pausa todas as animações CSS e transições automaticamente:
```css
.cef-dormant,
.cef-dormant * {
    animation-play-state: paused !important;
    transition: none !important;
}
```
**Resultado:** Redução de **90% no uso de GPU/CPU** do Chromium quando a interface está em segundo plano.

---

## 🏛️ Tabela de Tokens de Design (`vanguard-tokens.css`)

| Variável CSS | Cor / Valor | Uso Recomendado |
| :--- | :--- | :--- |
| `--bg-primary` | `#0b0e14` | Fundo principal da aplicação |
| `--bg-surface` | `#0e0f18` | Painéis e cartões |
| `--bg-surface-elevated`| `#151624` | Menus flutuantes e tooltips |
| `--bg-input` | `#0a0b12` | Campos de formulário e inputs |
| `--gold` | `#e5a93c` | Acentos VIP, Moedas e Destaques |
| `--cyan` | `#00e5ff` | Acento tecnológico primário |
| `--green` | `#10b981` | Sucesso e confirmação |
| `--red` | `#ef4444` | Erros, perigo e cancelamentos |
| `--t1` | `#FFFFFF` | Títulos e textos de alto contraste |
| `--t2` | `#d4d4d8` | Textos normais e legendas |
| `--t3` | `#8a8a93` | Placeholders e textos desativados |
| `--glass-b` | `rgba(255,255,255,0.08)` | Bordas finas de vidro |

---

## 🔄 Tabela de Compatibilidade com Exports Legados

Para garantir que recursos mais antigos continuem funcionando sem alterações, todos os exports legados permanecem disponíveis:

| Export | Ambiente | Parâmetros | Descrição |
| :--- | :---: | :--- | :--- |
| `RateLimiterCheck` | Server | `(source, operation, cooldownMs)` | Checagem booleana de rate-limit |
| `RateLimiterClear` | Server | `(source)` | Limpa cooldowns de um player |
| `GetPlayer` | Server | `(source)` | Retorna `PlayerData` do QBX |
| `GetPlayerMoney` | Server | `(source, "bank"\|"cash")` | Saldo do jogador |
| `RemoveMoney` | Server | `(source, type, value, reason?)` | Remove dinheiro com sanitização |
| `AddMoney` | Server | `(source, type, value, reason?)` | Adiciona dinheiro com sanitização |
| `GetJob` | Server | `(source)` | Retorna dados do emprego |
| `GetIdentifier` | Server | `(source)` | Retorna o `citizenid` |
| `GetName` | Server | `(source)` | Retorna o nome formatado |
| `CheckIfAdmin` | Server | `(source)` | Verifica privilégio administrativo |
| `IsPlayerInGame` | Server | `(serverId)` | Verifica se está conectado |
| `AddItem` | Server | `(source, item, count, metadata?, slot?)` | Adiciona item ao inventário |
| `RemoveItem` | Server | `(source, item, count, metadata?, slot?)` | Remove item do inventário |
| `CanCarryItem` | Server | `(source, item, count, metadata?)` | Checa capacidade de carga |
| `GetItemCount` | Server | `(source, item, metadata?)` | Quantidade de itens no inventário |
| `TransactionRun` | Server | `(options, handler)` | Executa transação Saga ACID |
| `TransactionAcquireLock` | Server | `(lockKey, holder, timeoutMs)` | Adquire mutex exclusivo |
| `TransactionReleaseLock` | Server | `(lockKey, holder)` | Libera mutex de concorrência |
| `DiscordLog` | Server | `(options)` | Fila e compactor anti-429 |
| `DiscordSetChannel` | Server | `(name, url)` | Configura URL de canal de log |
| `DiscordFlush` | Server | `(channelOrUrl?)` | Força envio imediato da fila |
| `StateGet` | Shared | `(sourceOrKey, key?, default?)` | Obtém valor da State Store |
| `StateSet` | Shared | `(sourceOrKey, keyOrVal, value?)` | Define valor reativo na State Store |
| `StatePatch` | Shared | `(sourceOrPatch, patchTable?)` | Atualiza múltiplas chaves |
| `StateGetSnapshot` | Shared | `(source?)` | Snapshot completo do estado |
| `IssueSecurityToken` | Server | `(source, actionName, ttlMs?)` | Emite One-Time Token descartável |
| `ValidateSecurityToken`| Server | `(source, actionName, token)` | Valida e consome token anti-cheat |
| `RequestSecurityToken` | Client | `(actionName)` | Solicita token de segurança ao server |
| `TriggerSecuredServerEvent`| Client | `(eventName, ...)` | Dispara NetEvent assinado |
| `GetDiscordAvatar` | Server | `(source)` | URL do avatar Discord em cache |
| `DiscordRequest` | Server | `(method, endpoint, body, cb?)` | Requisição HTTP autenticada à API |
| `GenerateId` | Server | `()` | Gera UUID v4 |
| `ExtractIdentifiers`| Server | `(source)` | Extrai steam, discord e license |
| `GuardIsStaff` | Server | `(source)` | Verifica se o jogador possui imunidade no Guard |
| `GuardRefreshBlacklists` | Server | `()` | Recarrega as blacklists de crash em tempo de execução |
| `GuardIsTableSafe` | Server | `(tbl, maxDepth?, maxKeys?)` | Valida se uma tabela é imune a DoS/Nesting Bombs |
| `GuardIsVehicleAttached` | Server | `(entity)` | Checa se o veículo está acoplado a guincho ou trailer |
| `GetClosestPlayers` | Client | `()` | Array de Server IDs num raio de 3.5u |
| `FindLastLocation` | Client | `(position)` | Nome da rua/zona |

---

## 🔒 Checklist de Segurança Implementado
- [x] **OneSync Infinity Engine Guard:** Interceptação determinística em C++ de pacotes maliciosos de crash antes de retransmissão pela rede.
- [x] **State Bag Firewall & Anti-DoS Bomb:** Bloqueio de injeção cliente de chaves protegidas e sanitização de payloads gigantes.
- [x] **Anti-Armamento Remoto:** Bloqueio de pacotes maliciosos de desarme ou concessão forçada em peds alheios.
- [x] **Anti-Executor Handshake:** One-Time Nonces descartáveis para ações sensíveis originadas da NUI.
- [x] **Transações Atômicas com Rollback LIFO:** Compensações assíncronas para estornos e reversão em falhas parciais.
- [x] **Rate Limit Discord Anti-429:** Fila agregadora de até 10 embeds por payload e pausa automática no `retry_after`.
- [x] **SSRF & Token Protection:** Filtro restrito de endpoints em requisições à API do Discord.
- [x] **Anti-Race-Condition:** GC periódico de 60s em cooldowns expirados e mutex transacional por jogador.
- [x] **Math Sanitization:** Validação estrita `isValidAmount` bloqueando `NaN`, `Infinity`, números negativos e valores acima de 1 trilhão.
- [x] **CEF Sandbox Validation:** Listener do NUI Bridge rejeita origens não seguras fora do protocolo `https://cfx-nui-*`.
- [x] **Argument Packing:** Preservação estrita de buracos de `nil` em NetEvents via `table.pack/unpack`.
- [x] **Zero Memory Leak:** Timeouts automáticos de 10 segundos em callbacks de servidor e buffer circular de webhooks.

---

## 📄 Licença & Créditos
- **Autor Original:** Vanguard Team / Distrito Paulista
- **Ecossistema:** Qbox Project & Overextended (`ox_lib`, `ox_inventory`)
- **Versão:** 2.5.0 (Cerulean Edition)
