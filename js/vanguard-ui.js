// =============================================================================
// Vanguard OS | UI-Kit & Preact + Twind DX Library
//
// Shared UI runtime for Vanguard OS micro-frontend apps.
// Provides:
// - Preact (h, render, Component)
// - Preact Hooks (useState, useEffect, useMemo, useCallback, useRef, etc.)
// - HTM (html tagged template literals for JSX-like syntax in plain JS)
// - Twind (Tailwind engine + Vanguard OS preset rules)
// - createPreactApp (Adapter bridge to publish Preact apps into Vue host OS)
// =============================================================================

import { h, render, Component, Fragment } from './preact.js';
import { useState, useEffect, useMemo, useCallback, useRef, useReducer, useContext } from './hooks.js';
import htm from './htm.js';

// Bind HTM to Preact's createElement (h)
export const html = htm.bind(h);

export {
    h,
    render,
    Component,
    Fragment,
    useState,
    useEffect,
    useMemo,
    useCallback,
    useRef,
    useReducer,
    useContext
};

/**
 * Initialize Twind Engine with Vanguard OS standard design tokens & rules
 */
export async function initTwind() {
    if (typeof window === 'undefined') return;
    if (!window.twind) {
        try {
            await new Promise((resolve, reject) => {
                const script = document.createElement('script');
                script.src = 'nui://vanguard_lib/js/twind.js';
                script.onload = resolve;
                script.onerror = reject;
                document.head.appendChild(script);
            });
        } catch (err) {
            console.error('[Vanguard UI-Kit] Failed to load Twind script:', err);
        }
    }

    if (window.twind && typeof window.twind.install === 'function') {
        try {
            window.twind.install({
                rules: [
                    ["col", { display: "flex", flexDirection: "column" }],
                    ["row", { display: "flex", flexDirection: "row" }],
                    ["aic", { alignItems: "center" }],
                    ["aifs", { alignItems: "flex-start" }],
                    ["aife", { alignItems: "flex-end" }],
                    ["jcfs", { justifyContent: "flex-start" }],
                    ["jcc", { justifyContent: "center" }],
                    ["jcfe", { justifyContent: "flex-end" }],
                    ["jcsb", { justifyContent: "space-between" }]
                ]
            });
        } catch (e) {
            // Already installed
        }
    }
}

/**
 * Bridge adapter to publish Preact root components seamlessly into Vanguard OS
 * 
 * @param {Function|Component} RootComponent Preact component
 * @returns {Object} Vue 3 component definition
 */
export function createPreactApp(RootComponent) {
    return {
        template: '<div ref="preactContainer" class="w-full h-full relative overflow-hidden" style="width:100%;height:100%;position:relative;overflow:hidden;"></div>',
        async mounted() {
            await initTwind();
            const container = this.$refs.preactContainer;
            if (container) {
                render(h(RootComponent, this.$props), container);
            }
        },
        beforeUnmount() {
            const container = this.$refs.preactContainer;
            if (container) {
                render(null, container);
            }
        }
    };
}
