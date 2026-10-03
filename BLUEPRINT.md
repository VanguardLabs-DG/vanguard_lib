# 🛡️ Vanguard Architecture Blueprint & LLM System Contract
> **Target Audience:** AI Assistants (LLMs), Senior Developers, and System Architects.  
> **Ecosystem:** FiveM / Distrito Paulista / Lua 5.4 / QBX Core / ox_inventory / vanguard_esc.  
> **Version:** 2.5.0 (Production Standard).

---

## 🎯 Purpose & Identity

When designing, refactoring, or generating code for resources that integrate with `vanguard_lib`, **YOU MUST STRICTLY ADHERE TO THIS CONTRACT**. Any script that breaks this contract creates security vulnerabilities (event injection), race conditions (item/money duplication), memory leaks, or Discord API rate limit blocks.

---

## 🛑 The 5 Golden Rules (MANDATORY CONTRACT)

### 1. Zero-Latency Import (No Raw Exports in Business Logic)
- **DO:**
  In `fxmanifest.lua`:
  ```lua
  shared_scripts {
      '@ox_lib/init.lua',
      '@vanguard_lib/init.lua'
  }
  ```
  Access all APIs via the global `vanguard` table in Lua:
  ```lua
  local money = vanguard.player.getMoney(source, 'bank')
  ```
- **DON'T:**
  Never use raw exports like `exports.vanguard_lib:GetPlayerMoney(source, 'bank')` in new resources. The `init.lua` module is faster, zero-latency, and type-checked.

---

### 2. Anti-Executor Handshake for NUI Actions (`requireToken = true`)
- **DO:**
  Any server event that triggers an economy, inventory, vehicle, or persistent state change from a user interface **MUST** require a One-Time Token (Nonce):
  ```lua
  vanguard.registerServerEvent('resource:sensitiveAction', {
      requireToken = true,                       -- Enforces one-time NUI nonce
      rateLimit = 1500,                          -- Rate limit per player
      validateArgs = { 'string', 'number' },     -- Strict runtime argument type validation
      requireAuth = true                         -- Blocks spoofed/null endpoints
  }, function(source, arg1, arg2)
      -- Handler code here
  end)
  ```
  In NUI (Microfrontends):
  ```javascript
  const plugin = new VanguardPlugin({ id: 'my_plugin' });
  // Automatic token request + signed payload
  await plugin.postSecureNui('resource:sensitiveAction', { arg1, arg2 });
  ```
- **DON'T:**
  **NEVER** register an action that awards items, money, or cars using standard `RegisterNetEvent` without `requireToken`. Cheaters inject these events directly via external DLL consoles (Eulen, RedEngine).

---

### 3. Distributed Transactions with Saga Rollback (`vanguard.transaction.run`)
- **DO:**
  Any flow that touches two or more entities (e.g. Money + Inventory, Money + Database, or Item + Database) **MUST** run within a transaction block:
  ```lua
  local success, result, err = vanguard.transaction.run({
      source = source,
      label = "resource_action_label",
      timeout = 6000
  }, function(tx)
      -- STEP 1: DEBIT FIRST (Money or Item)
      tx:removeMoney("bank", 5000, "Purchase Reason")
      
      -- STEP 2: PERSISTENCE (Database query)
      tx:dbInsert("INSERT INTO table_name (source, col) VALUES (?, ?)", { source, "val" }, "table_name")
      
      -- STEP 3: BENEFIT DELIVERY (Item or Reward)
      tx:addItem("bread", 2)
      
      return { success = true }
  end)

  if not success then
      -- Automatically rolled back in reverse (LIFO) order!
      -- Player did not lose money and no duplicate items were created.
      TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = err.message })
      return
  end
  ```
- **DON'T:**
  **NEVER** write loose sequences like:
  ```lua
  -- WRONG (DANGEROUS ANTI-PATTERN):
  vanguard.player.removeMoney(src, 'bank', 5000)
  -- If inventory is full or MySQL crashes here, player loses money and submits support tickets!
  vanguard.inventory.addItem(src, 'bread', 2)
  ```

---

### 4. Global Reactive State (NUI Pub/Sub) Instead of Event Spaghetti
- **DO:**
  When state needs to be displayed or synchronized across multiple menus (e.g., gems, VIP tier, battle pass level, bank balance):
  - On Server:
    ```lua
    vanguard.state.set(source, 'user.gems', 1200)
    -- or bulk update:
    vanguard.state.patch(source, { ['user.gems'] = 1200, ['vip.tier'] = 'gold' })
    ```
  - In NUI (Alpine.js / Vanilla JS):
    ```html
    <!-- Alpine.js is automatically reactive with $store.vanguard -->
    <span x-text="$store.vanguard.user?.gems || 0"></span>
    <span x-text="$store.vanguard.vip?.tier || 'free'"></span>
    ```
    Or in JavaScript:
    ```javascript
    plugin.state.subscribe('user.gems', (newGems, oldGems) => {
        console.log(`Gems updated to: ${newGems}`);
    });
    ```
- **DON'T:**
  **NEVER** create cascading custom NetEvents (e.g., `TriggerClientEvent('updateGems')`, `TriggerClientEvent('updateBank')`, `TriggerClientEvent('updateVIP')`) to refresh individual UI screens. Use the state store.

---

---

### 5. Resilient Discord Logging (Anti-Rate-Limit 429)
- **DO:**
  Log administrative and economic events using the buffered queue:
  ```lua
  vanguard.discord.log({
      channel = "financeiro", -- Pre-configured channel alias or convar
      priority = "normal",    -- "urgent" (250ms), "normal" (2s), "bulk" (5s)
      embed = {
          title = "💰 Transação Financeira",
          description = string.format("Jogador **%s** comprou item.", vanguard.player.getName(src)),
          color = 0x10b981
      }
  })
  ```
- **DON'T:**
  **NEVER** use `PerformHttpRequest` directly to Discord webhooks in high-traffic events. The Discord API returns `429 Too Many Requests`, causing silent log loss and network micro-stutters.

---

### 6. Autonomous OneSync Engine Guard (Zero-Config Infrastructure Defense)
- **DO:**
  Rely on `vanguard_lib`'s native OneSync Infinity C++ event interceptors for server-wide crash prevention and network integrity:
  - **Task Clearing:** Malicious `clearPedTasksEvent` packets on foreign peds (`quiet-uniform-jersey +631F8C`) are canceled at the engine level before reaching clients.
  - **Entity Instantiation:** Model 0, NaN/infinite coordinates, and crash meshes (`eight-nuts-august +133165C`) are blocked automatically in `entityCreating`.
  - **Explosion & Particle Floods:** Out-of-bounds `cameraShake`, `damageScale`, and particle scale manipulations (`october-hotel-echo +8BABCE`) are mathematically sanitized.
  - **Projectile & Weapon Overflows:** Anomalous velocities (> 450 u/s) and damage overflows (`black-aspen-tango +86601B`) are dropped instantly.
  - **State Bag Firewall:** Client injection of server-authority keys (`admin`, `money`, `godmode`, etc.) is dropped silently (`CancelEvent`), while DoS payloads (> 8KB or depth > 3) are sanitized.
  - **Remote Weapon Protection:** Attempts to disarm or force weapons on other players' peds (`owner ~= sender`) via `giveWeaponEvent` / `removeWeaponEvent` are canceled with immediate server-side strip.
  - **Vehicle Towing & Attachments:** Flatbeds and cargo trailers are detected via `isVehicleAttachedOrTowed`, exempting them from driver-presence false positives.
- **DON'T (THE 5-LAYER ESCALATION DOCTRINE):**
  - **NEVER AUTO-BAN BY HEURISTICS:** Auto-bans based on lag, desync, vehicle speed, or dynamic events are strictly forbidden.
  - **Layer 1 (Silent Drop):** Cancel packet via `CancelEvent()` — the cheat simply fails without alerting the attacker or disturbing laggy players.
  - **Layer 2 (Rate Limit):** Token bucket cooldown for sustained bursts.
  - **Layer 3 (Forensic Telemetry):** Structured Discord log with identifiers and JSON payload to `anticheat` channel.
  - **Layer 4 (Kick on Reincidence):** Disconnect only on extreme floods (> 3x threshold in 2s) or deterministic crash signatures (NaN, Model 0).
  - **Layer 5 (Ban by Staff):** Permanent bans are reserved exclusively for human staff via txAdmin HWID tokens.

---

## 🚫 Hall of Shame: Anti-Patterns to NEVER Write

| Anti-Pattern | Why it is Banned | Vanguard Replacement |
| :--- | :--- | :--- |
| `RegisterNetEvent('loja:comprar', function(item, preco) ...)` | **Cheat Vulnerability:** Cheaters pass `preco = 0` or negative values. | Use `vanguard.registerServerEvent` with `requireToken = true` and `validateArgs`. |
| `RemoveMoney(...)` then `AddItem(...)` loosely | **Duplication / Loss:** If server lags or inventory is full, money is lost. | Use `vanguard.transaction.run` with LIFO rollback. |
| Checking `exports.ox_inventory.AddItem` directly | **FiveM Crash:** Lua metatable stub throws `SCRIPT ERROR: No such export`. | Handled internally by `vanguard.inventory` using `GetResourceState`. |
| Writing `__proto__` or nested paths in NUI | **Prototype Pollution:** Can compromise CEF application sandbox. | Handled automatically by `VanguardStateStore`. |
| Raw `PerformHttpRequest` to Discord | **429 Lockout:** Lost logs and server lag. | Use `vanguard.discord.log`. |
| Writing client-side noclip/godmode threads | **False Positive Nightmare:** Flags desyncs, vehicle seats, cutscenes. | Rely on `vanguard_lib` OneSync Engine Guard server-side. |
| Client writing to `admin` / `money` StateBags | **Privilege Escalation:** Cheaters bypass server authority. | StateBag Firewall blocks client writes with `CancelEvent()`. |

---

## 📋 Complete Standard Boilerplate Template

When asked to generate a new script, use this complete template:

### 1. `fxmanifest.lua`
```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@vanguard_lib/init.lua'
}

client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

ui_page 'web/dist/index.html'
files { 'web/dist/**/*' }
```

### 2. `server/main.lua`
```lua
local currentResource = GetCurrentResourceName()

vanguard.registerServerEvent(currentResource .. ':purchase', {
    requireToken = true,
    rateLimit = 1500,
    validateArgs = { 'string', 'number' },
    requireAuth = true
}, function(source, itemId, amount)
    local unitPrice = 100 -- Look up in your server config
    local totalPrice = unitPrice * amount

    local success, result, err = vanguard.transaction.run({
        source = source,
        label = "purchase:" .. itemId
    }, function(tx)
        -- 1. Debit
        tx:removeMoney("bank", totalPrice, "Store Purchase: " .. itemId)
        
        -- 2. Deliver
        tx:addItem(itemId, amount)
        
        -- 3. Audit DB
        tx:dbInsert("INSERT INTO store_logs (source, item, amount, total) VALUES (?, ?, ?, ?)",
            { source, itemId, amount, totalPrice }, "store_logs")
            
        return { item = itemId, amount = amount }
    end)

    if not success then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = err.message or 'Erro ao concluir transação.'
        })
        return
    end

    vanguard.discord.log({
        channel = "financeiro",
        priority = "normal",
        embed = {
            title = "🛍️ Compra Efetuada",
            description = string.format("Player **%s** comprou **%dx %s** por **$%d**.", 
                vanguard.player.getName(source), amount, itemId, totalPrice),
            color = 0x10b981
        }
    })

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = 'Compra realizada com sucesso!'
    })
end)
```

### 3. `web/script.js`
```javascript
const plugin = new VanguardPlugin({
    id: 'my_store',
    onInit: () => console.log('Store initialized')
});

async function buyItem(itemId, amount) {
    try {
        const response = await plugin.postSecureNui('my_store:purchase', {
            itemId: itemId,
            amount: Number(amount)
        });
        return response;
    } catch (err) {
        console.error('Secure purchase failed:', err);
    }
}
```
