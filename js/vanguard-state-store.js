/**
 * vanguard-state-store.js — Global Reactive State Engine for FiveM Microfrontends
 * Part of Vanguard Library (vanguard_lib v2.x)
 * 
 * Provides unified cross-iframe Pub/Sub reactivity with dot-notation path resolution,
 * automatic Host/Plugin synchronization, and native Alpine.js integration.
 */

"use strict";

(function (window) {
    const DANGEROUS_KEYS = new Set(['__proto__', 'constructor', 'prototype']);

    /**
     * Auxiliar seguro para ler caminhos com notação de ponto (ex: "player.vip.tier")
     */
    function getNestedValue(obj, path, defaultValue) {
        if (!obj || typeof obj !== 'object' || typeof path !== 'string') return defaultValue;
        const keys = path.split('.');
        let current = obj;
        for (const k of keys) {
            if (DANGEROUS_KEYS.has(k)) {
                return defaultValue;
            }
            if (current === null || current === undefined || typeof current !== 'object') {
                return defaultValue;
            }
            current = current[k];
        }
        return current !== undefined ? current : defaultValue;
    }

    /**
     * Auxiliar seguro para definir valores em caminhos com notação de ponto
     */
    function setNestedValue(obj, path, value) {
        if (!obj || typeof obj !== 'object' || typeof path !== 'string') return undefined;
        const keys = path.split('.');
        for (const k of keys) {
            if (DANGEROUS_KEYS.has(k)) {
                console.warn(`[VanguardStateStore] Bloqueada tentativa de prototype pollution na chave: '${k}'`);
                return undefined;
            }
        }
        let current = obj;
        for (let i = 0; i < keys.length - 1; i++) {
            const k = keys[i];
            if (!current[k] || typeof current[k] !== 'object') {
                current[k] = {};
            }
            current = current[k];
        }
        const lastKey = keys[keys.length - 1];
        const oldValue = current[lastKey];
        current[lastKey] = value;
        return oldValue;
    }

    class VanguardStateStore {
        /**
         * @param {Object} options
         * @param {boolean} [options.isHost=false] Se true, atua como Master Host (vanguard_esc)
         * @param {Object} [options.initialState={}] Estado inicial
         * @param {string} [options.pluginId=''] Identificador do plugin consumidor
         * @param {Function} [options.onDispatchPatch] Callback customizado de despacho para o host
         */
        constructor(options = {}) {
            this.isHost = !!options.isHost;
            this.pluginId = options.pluginId || '';
            this.state = options.initialState || {};
            this.subscribers = new Map(); // key -> Set<Function>
            this.wildcardSubscribers = new Set(); // Set<Function>
            this.onDispatchPatch = options.onDispatchPatch || null;

            this._setupWindowListener();
        }

        /**
         * Retorna uma cópia profunda (snapshot) do estado atual
         */
        getState() {
            try {
                return JSON.parse(JSON.stringify(this.state));
            } catch (_) {
                return { ...this.state };
            }
        }

        /**
         * Obtém o valor de uma chave (suporta dot notation)
         * @param {string} path Ex: "gems" ou "player.money.bank"
         * @param {*} [defaultValue=null]
         */
        get(path, defaultValue = null) {
            if (!path) return this.getState();
            return getNestedValue(this.state, path, defaultValue);
        }

        /**
         * Define um valor no estado e notifica os ouvintes
         * @param {string} path Chave ou caminho com ponto
         * @param {*} value Novo valor
         * @param {boolean} [silent=false] Se true, não re-despacha para o host
         */
        set(path, value, silent = false) {
            const oldValue = setNestedValue(this.state, path, value);

            // Notifica inscritos específicos
            this._notifyPath(path, value, oldValue);

            // Se for plugin filho e não for silent, despacha mutação para o Host
            if (!this.isHost && !silent) {
                this._dispatchToHost('mri-state/patch', { [path]: value });
            }

            // Se for Master Host, faz broadcast para todos os iframes ativos
            if (this.isHost && !silent) {
                this.broadcastSync(path, value);
            }

            return value;
        }

        /**
         * Atualiza múltiplas chaves de uma vez
         * @param {Object} patchObj
         * @param {boolean} [silent=false]
         */
        patch(patchObj, silent = false) {
            if (!patchObj || typeof patchObj !== 'object') return;
            for (const [path, val] of Object.entries(patchObj)) {
                this.set(path, val, true);
            }

            if (!this.isHost && !silent) {
                this._dispatchToHost('mri-state/patch', patchObj);
            }

            if (this.isHost && !silent) {
                this.broadcastSync(null, null, patchObj);
            }
        }

        /**
         * Inscreve um ouvinte para uma chave específica
         * @param {string} path Ex: "gems"
         * @param {Function} callback function(newValue, oldValue, path)
         * @returns {Function} Função de cancelamento (unsubscribe)
         */
        subscribe(path, callback) {
            if (!this.subscribers.has(path)) {
                this.subscribers.set(path, new Set());
            }
            this.subscribers.get(path).add(callback);

            // Executa imediatamente com o valor atual se existente
            const currentVal = this.get(path);
            if (currentVal !== undefined && currentVal !== null) {
                try {
                    callback(currentVal, undefined, path);
                } catch (err) {
                    console.error(`[VanguardStateStore] Erro no listener inicial de '${path}':`, err);
                }
            }

            return () => {
                const set = this.subscribers.get(path);
                if (set) set.delete(callback);
            };
        }

        /**
         * Inscreve um ouvinte para qualquer alteração de estado
         * @param {Function} callback function(path, newValue, oldValue, fullState)
         * @returns {Function} Função de cancelamento
         */
        subscribeAll(callback) {
            this.wildcardSubscribers.add(callback);
            return () => this.wildcardSubscribers.delete(callback);
        }

        /**
         * Notifica inscritos de um caminho e correntes pai/filho
         */
        _notifyPath(path, newValue, oldValue) {
            // Ouvintes exatos
            const listeners = this.subscribers.get(path);
            if (listeners) {
                listeners.forEach(cb => {
                    try { cb(newValue, oldValue, path); } catch (e) { console.error(e); }
                });
            }

            // Ouvintes wildcard globais
            this.wildcardSubscribers.forEach(cb => {
                try { cb(path, newValue, oldValue, this.state); } catch (e) { console.error(e); }
            });
        }

        /**
         * Despacha uma mutação para a janela pai (vanguard_esc)
         */
        _dispatchToHost(type, patch) {
            if (this.onDispatchPatch && typeof this.onDispatchPatch === 'function') {
                this.onDispatchPatch(type, patch);
                return;
            }

            if (window.parent && window.self !== window.top) {
                try {
                    window.parent.postMessage({
                        type: type || 'mri-state/patch',
                        pluginId: this.pluginId,
                        patch: JSON.parse(JSON.stringify(patch))
                    }, '*');
                } catch (err) {
                    console.error('[VanguardStateStore] Erro ao enviar postMessage para o Host:', err);
                }
            }
        }

        /**
         * Executado apenas pelo Host: transmite sincronização a todos os iframes montados
         */
        broadcastSync(path, value, bulkPatch) {
            const iframes = document.querySelectorAll('iframe[id^="plugin-iframe-"]');
            const payload = {
                type: 'mri-state/sync',
                path: path || null,
                value: value !== undefined ? value : null,
                patch: bulkPatch || (path ? { [path]: value } : {}),
                state: this.getState()
            };

            const clean = JSON.parse(JSON.stringify(payload));
            iframes.forEach(iframe => {
                if (iframe.contentWindow) {
                    try {
                        iframe.contentWindow.postMessage(clean, '*');
                    } catch (_) {}
                }
            });
        }

        /**
         * Escuta mensagens de sincronização recebidas
         */
        _setupWindowListener() {
            window.addEventListener('message', (event) => {
                // Proteção CEF: Rejeita mensagens vindas de origens externas não confiáveis
                if (event.origin && event.origin !== 'null' && !event.origin.startsWith('https://cfx-nui-') && !event.origin.startsWith('nui://')) {
                    return;
                }

                const data = event.data;
                if (!data || typeof data !== 'object') return;

                const type = data.type || data.action;

                // 1. Mensagem de sincronização vinda do Host para os Plugins filhos
                if (type === 'mri-state/sync' && !this.isHost) {
                    if (data.patch && typeof data.patch === 'object') {
                        for (const [k, v] of Object.entries(data.patch)) {
                            this.set(k, v, true); // true = silent para não re-emitir
                        }
                    } else if (data.path) {
                        this.set(data.path, data.value, true);
                    }
                }

                // 2. Mensagem de patch enviada por um Plugin filho para o Host
                if (type === 'mri-state/patch' && this.isHost) {
                    if (data.patch && typeof data.patch === 'object') {
                        // Aplica o patch no Host Store e propaga broadcast para os demais iframes
                        this.patch(data.patch, false);
                    }
                }
            });
        }

        /**
         * Integração automática com Alpine.js
         * @param {Object} [alpine] Instância global do Alpine
         */
        bindAlpine(alpine) {
            const A = alpine || window.Alpine;
            if (!A) return;

            // Registra um store reativo no Alpine
            if (A.store) {
                A.store('vanguard', this.state);
                // Mantém o store do Alpine atualizado quando o StateStore mudar
                this.subscribeAll((path, val) => {
                    const store = A.store('vanguard');
                    if (store) {
                        setNestedValue(store, path, val);
                    }
                });
            }

            // Registra helper mágico $vState
            if (A.magic) {
                A.magic('vState', () => this);
            }
        }
    }

    window.VanguardStateStore = VanguardStateStore;
})(window);
