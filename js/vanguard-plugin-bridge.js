/**
 * vanguard-plugin-bridge.js — Official Vanguard ESC Microfrontend SDK (v2.1)
 * Provides standardized lifecycle management, deep sleep dormancy,
 * keyboard trap prevention, zero-boilerplate communication, and
 * Global Reactive State Store (NUI Pub/Sub).
 */

"use strict";

(function (window) {
    class VanguardPlugin {
        constructor(config = {}) {
            this.id = config.id || 'unnamed_plugin';
            this.resource = config.resource || (typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : '');
            this.isEmbedded = (window.self !== window.top);
            this.isVisible = false;
            this.callbacks = {
                onInit: config.onInit || (() => {}),
                onVisibility: config.onVisibility || (() => {}),
                onNavigate: config.onNavigate || (() => {}),
                onUpdateGems: config.onUpdateGems || (() => {})
            };
            this.modalChecker = config.isModalOpen || (() => false);
            this.modalCloser = config.closeModal || (() => {});

            // Inicialização da State Store Global
            if (window.VanguardStateStore) {
                this.state = new window.VanguardStateStore({
                    pluginId: this.id,
                    isHost: false,
                    initialState: config.initialState || {}
                });
            } else {
                // Fallback interno leve se vanguard-state-store.js não for carregado previamente
                this.state = this._createInternalStateStore(config.initialState || {});
            }

            // Standalone Gate: If not inside host and standalone disallowed, hide immediately
            if (!this.isEmbedded && !config.allowStandalone) {
                console.warn(`[VanguardPlugin:${this.id}] Standalone execution blocked. Microfrontends run inside vanguard_esc.`);
                if (document.documentElement) document.documentElement.style.display = 'none';
                return;
            }

            this._setupListeners();
            this._setupKeyboardTrapFailsafe();
            this._handshake();

            // Integração automática se o Alpine já estiver presente no window
            if (window.Alpine && this.state.bindAlpine) {
                this.state.bindAlpine(window.Alpine);
            }
        }

        _createInternalStateStore(initialState) {
            const state = { ...initialState };
            const subs = new Map();
            const wildcardSubs = new Set();

            return {
                get: (k, def) => (state[k] !== undefined ? state[k] : def),
                set: (k, v, silent) => {
                    const old = state[k];
                    state[k] = v;
                    if (subs.has(k)) subs.get(k).forEach(cb => cb(v, old, k));
                    wildcardSubs.forEach(cb => cb(k, v, old, state));
                    if (!silent && this.isEmbedded) {
                        this.emitHost('mri-state/patch', { [k]: v });
                    }
                    return v;
                },
                patch: (obj, silent) => {
                    if (!obj || typeof obj !== 'object') return;
                    for (const [k, v] of Object.entries(obj)) {
                        this.state.set(k, v, true);
                    }
                    if (!silent && this.isEmbedded) {
                        this.emitHost('mri-state/patch', obj);
                    }
                },
                subscribe: (k, cb) => {
                    if (!subs.has(k)) subs.set(k, new Set());
                    subs.get(k).add(cb);
                    if (state[k] !== undefined) cb(state[k], undefined, k);
                    return () => { const s = subs.get(k); if (s) s.delete(cb); };
                },
                subscribeAll: (cb) => {
                    wildcardSubs.add(cb);
                    return () => wildcardSubs.delete(cb);
                },
                getState: () => ({ ...state }),
                bindAlpine: (A) => {
                    if (!A || !A.store) return;
                    A.store('vanguard', state);
                    if (A.magic) A.magic('vState', () => this.state);
                }
            };
        }

        _handshake() {
            const sendReady = () => {
                this.emitHost('mri-plugin/ready', { pluginId: this.id });
            };
            sendReady();
            setTimeout(sendReady, 100);
            setTimeout(sendReady, 350);
        }

        _setupListeners() {
            window.addEventListener('message', (event) => {
                if (event.source !== window.parent) return;
                // Proteção CEF: Rejeita mensagens vindas de origens externas não confiáveis
                if (event.origin && event.origin !== 'null' && !event.origin.startsWith('https://cfx-nui-') && !event.origin.startsWith('nui://')) {
                    return;
                }
                const data = event.data;
                if (!data) return;

                const type = data.type || data.action;
                switch (type) {
                    case 'mri-plugin/init':
                        this.isVisible = true;
                        if (document.documentElement) {
                            document.documentElement.classList.remove('cef-dormant');
                        }
                        // Hidratação do estado compartilhado a partir do Host
                        const initialPayloadState = data.state || data.payload?.state;
                        if (initialPayloadState && typeof initialPayloadState === 'object') {
                            this.state.patch(initialPayloadState, true);
                        }
                        this.callbacks.onInit({ ...data, ...(data.payload || {}) });
                        break;

                    case 'mri-plugin/visibility':
                        const vis = !!(data.visible !== undefined ? data.visible : data.payload?.visible);
                        this.isVisible = vis;
                        // Deep Sleep Protocol: Toggle dormancy on HTML to pause CSS animations & shaders
                        if (document.documentElement) {
                            document.documentElement.classList.toggle('cef-dormant', !vis);
                        }
                        this.callbacks.onVisibility(vis);
                        break;

                    case 'mri-plugin/navigate':
                        this.isVisible = true;
                        if (document.documentElement) {
                            document.documentElement.classList.remove('cef-dormant');
                        }
                        this.callbacks.onNavigate({ ...data, ...(data.payload || {}) });
                        break;

                    case 'mri-state/sync':
                        // Sincronização reativa recebida do Host
                        // Evita execução duplicada: se this.state for instância de VanguardStateStore, ele já processa em seu próprio listener
                        if (!window.VanguardStateStore || !(this.state instanceof window.VanguardStateStore)) {
                            if (data.patch && typeof data.patch === 'object') {
                                this.state.patch(data.patch, true);
                            } else if (data.path) {
                                this.state.set(data.path, data.value, true);
                            }
                        }
                        break;

                    case 'mri-plugin/updateGems':
                        if (data.gems !== undefined) {
                            const totalGems = Number(data.gems) || 0;
                            this.state.set('gems', totalGems, true);
                            this.callbacks.onUpdateGems(totalGems);
                        }
                        break;
                }
            });
        }

        _setupKeyboardTrapFailsafe() {
            // High-priority capture phase listener to resolve input focus traps
            window.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    e.preventDefault();
                    e.stopPropagation();

                    // Force blur active input to prevent lingering CEF keyboard focus
                    if (document.activeElement && typeof document.activeElement.blur === 'function') {
                        document.activeElement.blur();
                    }

                    let isModalOpen = false;
                    try {
                        isModalOpen = !!(this.modalChecker && this.modalChecker());
                    } catch (_) {
                        isModalOpen = false;
                    }

                    if (isModalOpen) {
                        try {
                            if (this.modalCloser) this.modalCloser();
                        } catch (_) {}
                        return;
                    }

                    this.close();
                }
            }, true); // useCapture = true is critical in CEF
        }

        emitHost(type, payload = {}) {
            if (this.isEmbedded && window.parent) {
                try {
                    // Strip Alpine.js reactive Proxies and symbols
                    const clean = JSON.parse(JSON.stringify({ type, pluginId: this.id, ...payload }));
                    window.parent.postMessage(clean, '*');
                } catch (err) {
                    console.error(`[VanguardPlugin:${this.id}] postMessage error:`, err);
                }
            }
        }

        close() {
            this.emitHost('mri-plugin/request-close');
        }

        openTab(tabId) {
            this.emitHost('mri-plugin/open-tab', { tab: tabId });
        }

        updateGems(gems) {
            const numGems = Number(gems) || 0;
            this.state.set('gems', numGems);
            this.emitHost('mri-plugin/notify', { action: 'updateGems', gems: numGems });
        }

        async postNui(action, data = {}) {
            try {
                const res = await fetch(`https://${this.resource}/${action}`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(data)
                });
                const text = await res.text();
                return text ? JSON.parse(text) : null;
            } catch (err) {
                console.error(`[VanguardPlugin:${this.id}] postNui error on ${action}:`, err);
                return null;
            }
        }

        /**
         * Solicita um token descartável One-Time para uma ação sensível (Anti-Executor)
         * @param {string} actionName
         * @returns {Promise<string|null>}
         */
        async requestSecureToken(actionName) {
            try {
                const res = await fetch(`https://${this.resource}/vanguard:security:requestToken`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ action: actionName })
                });
                const data = await res.json();
                return data?.token || null;
            } catch (err) {
                try {
                    const fallbackRes = await fetch(`https://vanguard_lib/vanguard:security:requestToken`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ action: actionName })
                    });
                    const data = await fallbackRes.json();
                    return data?.token || null;
                } catch (_) {
                    console.error(`[VanguardPlugin:${this.id}] Falha ao solicitar secure token para ${actionName}`);
                    return null;
                }
            }
        }

        /**
         * Executa um postNui assinado com One-Time Token gerado automaticamente
         * @param {string} action
         * @param {Object} data
         * @returns {Promise<any>}
         */
        async postSecureNui(action, data = {}) {
            const token = await this.requestSecureToken(action);
            return this.postNui(action, { ...data, __secToken: token });
        }
    }

    window.VanguardPlugin = VanguardPlugin;
})(window);
