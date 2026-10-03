/**
 * =========================================================================
 * vanguard-nui.ts | Vanguard Modern NUI & Anti-Executor SDK
 * Compatível com Vite, React, Svelte, Vue e TypeScript
 * =========================================================================
 */

export interface NuiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
}

// Detecção de ambiente: Browser comum de desenvolvimento (localhost) vs FiveM CEF
export const isEnvBrowser = (): boolean => !(window as any).invokeNative && !(window as any).GetParentResourceName;

/**
 * Retorna o nome do recurso FiveM atual ou fallback seguro para browser
 */
export const getResourceName = (): string => {
  if (isEnvBrowser()) return 'mock_resource';
  return (window as any).GetParentResourceName ? (window as any).GetParentResourceName() : 'vanguard_lib';
};

/**
 * Requisição NUI padrão com proteção contra timeout e suporte a Mock de Dev
 */
export async function fetchNui<T = any>(
  event: string,
  data?: any,
  mockResponse?: T,
  timeoutMs: number = 10000
): Promise<T> {
  if (isEnvBrowser()) {
    console.debug(`[VanguardNUI Mock] Fetching event: '${event}' with payload:`, data);
    if (mockResponse !== undefined) {
      await new Promise((r) => setTimeout(r, 200)); // Simula latência de rede
      return mockResponse;
    }
    return {} as T;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const resource = getResourceName();
    const resp = await fetch(`https://${resource}/${event}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
      signal: controller.signal,
    });

    const text = await resp.text();
    return text ? JSON.parse(text) : null;
  } catch (err: any) {
    if (err.name === 'AbortError') {
      console.error(`[VanguardNUI] Timeout de ${timeoutMs}ms excedido aguardando resposta para '${event}'.`);
      throw new Error(`NUI Callback timeout on '${event}'`);
    }
    console.error(`[VanguardNUI] Falha ao comunicar com '${event}':`, err);
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Solicita um One-Time Token (Nonce) ao subsistema de segurança do vanguard_lib
 */
export async function requestSecurityToken(actionName: string): Promise<string | null> {
  if (isEnvBrowser()) {
    return 'mock_sec_token_' + Math.random().toString(36).substring(2, 9);
  }

  try {
    // 1. Tenta requisitar pelo próprio resource
    const res = await fetchNui<{ token?: string }>('vanguard:security:requestToken', { action: actionName }, undefined, 3000);
    if (res?.token) return res.token;
  } catch (_) {
    // 2. Fallback direto para o endpoint global do vanguard_lib
    try {
      const resp = await fetch(`https://vanguard_lib/vanguard:security:requestToken`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: actionName }),
      });
      const data = await resp.json();
      return data?.token || null;
    } catch (err) {
      console.error(`[VanguardSecurity] Falha crítica ao obter token para '${actionName}':`, err);
      return null;
    }
  }
  return null;
}

/**
 * Executa requisição NUI com handshake Anti-Executor automático (One-Time Token injetado)
 * Use para qualquer ação sensível (compras, transferência, spawn de veículos, recompensas)
 */
export async function fetchNuiSecure<T = any>(
  event: string,
  data: Record<string, any> = {},
  mockResponse?: T
): Promise<T> {
  // Passo 1: Obtenção segura do Nonce
  const token = await requestSecurityToken(event);
  if (!token) {
    throw new Error(`[VanguardSecurity] Operação abortada: Não foi possível obter token de segurança para '${event}'.`);
  }

  // Passo 2: Despacho com token descartável anexado
  return fetchNui<T>(event, { ...data, __secToken: token }, mockResponse);
}

/**
 * Hook / Utilitário para escutar eventos vindos do Client Lua (SendNUIMessage)
 */
export function useNuiEvent<T = any>(action: string, handler: (data: T) => void): () => void {
  const listener = (event: MessageEvent) => {
    const { action: eventAction, data } = event.data || {};
    if (eventAction === action) {
      handler(data);
    }
  };

  window.addEventListener('message', listener);
  return () => window.removeEventListener('message', listener);
}
