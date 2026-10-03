---@meta
-- =========================================================================
-- VANGUARD LIBRARY v2.5.0 | LuaLS Type Definitions
-- Autocomplete e validação estática de tipos para o ecossistema Vanguard
-- =========================================================================

---@class VanguardPlayerIdentifiers
---@field steam? string
---@field discord? string
---@field license? string
---@field xbl? string
---@field live? string
---@field fivem? string

---@class VanguardDiscordEmbedAuthor
---@field name string
---@field url? string
---@field icon_url? string

---@class VanguardDiscordEmbedField
---@field name string
---@field value string
---@field inline? boolean

---@class VanguardDiscordEmbedFooter
---@field text string
---@field icon_url? string

---@class VanguardDiscordEmbed
---@field title? string
---@field description? string
---@field url? string
---@field color? integer Cor em formato hexadecimal (ex: 0x10b981)
---@field author? VanguardDiscordEmbedAuthor
---@field fields? VanguardDiscordEmbedField[]
---@field footer? VanguardDiscordEmbedFooter
---@field timestamp? string ISO 8601 Timestamp

---@alias VanguardDiscordPriority '"urgent"' | '"normal"' | '"bulk"'
---@alias VanguardMoneyType '"bank"' | '"cash"' | '"gems"' | '"crypto"' | string

---@class VanguardDiscordLogOptions
---@field channel string Nome do canal configurado (ex: "financeiro", "anticheat") ou webhook URL
---@field priority? VanguardDiscordPriority Prioridade de despacho (default: "normal")
---@field embed? VanguardDiscordEmbed Embed rico do Discord
---@field content? string Mensagem de texto simples

---@class VanguardTransactionError
---@field isTxFailure boolean
---@field step string Nome do passo que falhou
---@field message string Motivo da falha
---@field code? string Código de erro (ex: "LOCKED")

---@class VanguardTransactionOptions
---@field source? integer Server ID do jogador associado (obrigatório para operações financeiras e inventário)
---@field label? string Identificador amigável para telemetria e logs (ex: "loja:comprar_carro")
---@field timeout? number Tempo limite em milissegundos para liberação do lock (padrão: 6000ms)
---@field lock? boolean Se deve adquirir trava exclusiva de execução para este source (padrão: true se source existir)
---@field lockKey? string Chave customizada de trava de concorrência
---@field onRollback? fun(err: VanguardTransactionError, tx: VanguardTransactionContext) Callback disparado em caso de rollback
---@field onCommit? fun(result: any, tx: VanguardTransactionContext) Callback disparado no commit com sucesso

---@class VanguardCustomStepDef
---@field name string Nome do passo para rastreamento
---@field execute fun(tx: VanguardTransactionContext): any Função executora (retornar false ou disparar erro aciona rollback)
---@field compensate fun(result: any) Função que desfaz a alteração caso passos subsequentes falhem

---@class VanguardTransactionContext
---@field id string UUID v4 único da transação
---@field label string Label da transação
---@field source? integer Server ID do jogador
---@field citizenid? string CitizenID do jogador para compensação offline
---@field state '"pending"' | '"running"' | '"committed"' | '"rolled_back"' | '"failed"'
---@field step fun(self: VanguardTransactionContext, stepDef: VanguardCustomStepDef): any Executa um passo customizado com compensação
---@field removeMoney fun(self: VanguardTransactionContext, moneyType: VanguardMoneyType, amount: number, reason?: string): boolean Debita dinheiro com compensação automática por estorno
---@field addMoney fun(self: VanguardTransactionContext, moneyType: VanguardMoneyType, amount: number, reason?: string): boolean Credita dinheiro com compensação automática por débito
---@field removeGems fun(self: VanguardTransactionContext, amount: number, reason?: string): boolean Atalho para debitar gemas VIP
---@field addGems fun(self: VanguardTransactionContext, amount: number, reason?: string): boolean Atalho para creditar gemas VIP
---@field addItem fun(self: VanguardTransactionContext, item: string, count?: number, metadata?: table, slot?: number): boolean Adiciona item com validação de peso e compensação por remoção
---@field removeItem fun(self: VanguardTransactionContext, item: string, count?: number, metadata?: table, slot?: number): boolean Remove item com compensação por devolução
---@field dbInsert fun(self: VanguardTransactionContext, query: string, params: any[], tableOrCompensate: string | fun(insertId: number)): number Insere registro no MySQL com rollback automático via DELETE FROM table WHERE id = ?
---@field fail fun(self: VanguardTransactionContext, reason: string): nil Aborta a transação explicitamente e inicia o rollback em cascata LIFO

---@alias VanguardArgType '"string"' | '"number"' | '"boolean"' | '"table"' | '"any"' | '"pos_int"' | '"pos_number"' | '"?string"' | '"?number"' | '"?boolean"' | '"?table"' | '"?pos_int"' | '"?pos_number"'

---@class VanguardRegisterEventOptions
---@field requireToken? boolean Exige Nonce descartável da NUI (Anti-Executor). Remove o token dos args antes de repassar ao handler.
---@field rateLimit? number Cooldown mínimo em ms entre execuções por jogador (Anti-Spam / Race-Condition)
---@field validateArgs? VanguardArgType[] Validação estrita de tipos dos argumentos. Suporta opcionais com prefixo "?"
---@field requireAuth? boolean Garante que o endpoint de rede do jogador é autêntico e válido (Anti-Spoof)
---@field onSecurityViolation? fun(source: integer, eventName: string, token?: any) Callback para violações de segurança
---@field onRateLimited? fun(source: integer, eventName: string) Callback quando o jogador atinge o rate limit
---@field onValidationFailed? fun(source: integer, paramIndex: integer, expectedType: string, actualType: string) Callback para tipagem inválida

---@class VanguardPlayerModule
---@field get fun(source: integer | string): table | nil Retorna o objeto Player do QBX Core
---@field getMoney fun(source: integer | string, moneyType: VanguardMoneyType): number Retorna o saldo do jogador
---@field addMoney fun(source: integer | string, moneyType: VanguardMoneyType, amount: number, reason?: string): boolean Adiciona dinheiro com auditoria
---@field removeMoney fun(source: integer | string, moneyType: VanguardMoneyType, amount: number, reason?: string): boolean Remove dinheiro com auditoria
---@field getGems fun(source: integer | string): number Retorna o saldo de gemas VIP
---@field addGems fun(source: integer | string, amount: number, reason?: string): boolean Adiciona gemas VIP com auditoria
---@field removeGems fun(source: integer | string, amount: number, reason?: string): boolean Remove gemas VIP com auditoria
---@field getJob fun(source: integer | string): string, integer, string, string Retorna: name, grade, label, gradename
---@field getCitizenId fun(source: integer | string): string | nil Retorna o CitizenID do personagem
---@field getName fun(source: integer | string): string Retorna o nome formatado do personagem
---@field isAdmin fun(source: integer | string): boolean Verifica se o jogador possui permissão administrativa
---@field isOnline fun(source: integer | string): boolean Verifica se o jogador está conectado no servidor
---@field getIdentifiers fun(source: integer | string): VanguardPlayerIdentifiers Retorna Steam, Discord e License

---@class VanguardDiscordModule
---@field log fun(options: VanguardDiscordLogOptions): boolean Enfileira um log com agrupamento de até 10 embeds e anti-429
---@field getAvatar fun(source: integer | string): string | nil Retorna a URL do avatar Discord em cache
---@field request fun(method: '"GET"' | '"POST"' | '"PATCH"', endpoint: string, body?: table | string, cb?: fun(res: table | nil)): table | nil
---@field setChannel fun(name: string, webhookUrl: string): nil Configura o canal de webhook
---@field flush fun(channelOrUrl?: string): nil Força o esvaziamento imediato da fila de logs

---@class VanguardTransactionModule
---@field run fun(options: VanguardTransactionOptions, handler: fun(tx: VanguardTransactionContext): any): boolean, any, VanguardTransactionError? Executa transação distribuída ACID com rollback LIFO
---@field lock fun(lockKey: string, holder: any, timeoutMs?: number): boolean Adquire trava exclusiva de concorrência
---@field unlock fun(lockKey: string, holder?: any): nil Libera trava de concorrência

---@class VanguardStateModule
---@field set fun(source: integer | string, key: string, value: any): nil Define chave de estado (Server/Client)
---@field get fun(source: integer | string, key: string, defaultValue?: any): any Obtém valor de chave de estado
---@field patch fun(source: integer | string, patchTable: table): nil Aplica patch em lote no estado
---@field getSnapshot fun(source: integer | string): table Retorna snapshot completo do estado

---@class VanguardSecurityModule
---@field issueToken fun(source: integer | string, actionName: string, ttlMs?: number): string | nil Emite token de uso único (Server)
---@field validateToken fun(source: integer | string, actionName: string, token: string): boolean Valida e consome token (Server)
---@field requestToken fun(actionName: string): string | nil Solicita token descartável (Client)
---@field triggerSecuredServerEvent fun(eventName: string, ...: any): boolean Dispara NetEvent com token automático (Client)

---@class VanguardGuardModule
---@field isStaff fun(source: integer | string): boolean Verifica se possui imunidade administrativa no Guard
---@field refreshBlacklists fun(): boolean Recarrega blacklists de crash em runtime
---@field isTableSafe fun(tbl: table, maxDepth?: number, maxKeys?: number): boolean Checa se tabela é segura contra DoS
---@field isVehicleAttached fun(entity: integer): boolean Checa se veículo está em reboque ou guincho

---@class VanguardInventoryModule
---@field addItem fun(source: integer | string, item: string, count?: number, metadata?: table, slot?: number): boolean
---@field removeItem fun(source: integer | string, item: string, count?: number, metadata?: table, slot?: number): boolean
---@field canCarryItem fun(source: integer | string, item: string, count?: number, metadata?: table): boolean
---@field getItemCount fun(source: integer | string, item: string, metadata?: table): number

---@class VanguardGlobal
---@field isServer boolean
---@field version string
---@field libResource string
---@field player VanguardPlayerModule
---@field inventory VanguardInventoryModule
---@field discord VanguardDiscordModule
---@field transaction VanguardTransactionModule
---@field state VanguardStateModule
---@field security VanguardSecurityModule
---@field guard VanguardGuardModule
---@field rateLimit fun(source: integer, operation: string, cooldownMs: number): boolean
---@field clearRateLimit fun(source: integer): nil
---@field uuid fun(): string Retorna UUID v4 RFC 4122
---@field registerServerEvent fun(eventName: string, options: VanguardRegisterEventOptions | fun(source: integer, ...: any), handler?: fun(source: integer, ...: any)): nil Registra NetEvent com proteções integradas

---@type VanguardGlobal
vanguard = {}
