# 📦 Vanguard Local CDN & Microfrontends Vendor Guide

Este diretório funciona como o **CDN Local Offline** para todas as interfaces NUI (CEF) do servidor.  
Nenhum script precisa baixar ou incluir bibliotecas repetidas na sua pasta. Todas as stacks são servidas diretamente pela `vanguard_lib` com latência zero e 100% offline.

---

## 📚 Stacks Disponíveis & Como Usar no HTML

### 1. 🟢 Vue 3 (Produção Minificada)
Ideal para interfaces reativas completas sem necessidade de compilação ou Node.js.

```html
<!-- CDN Local -->
<script src="https://cfx-nui-vanguard_lib/vendor/vue/vue.global.prod.js"></script>

<div id="app">
    <div class="card bg-primary text-white p-4">
        <h1>{{ title }}</h1>
        <p>Saldo: R$ {{ saldo }}</p>
        <button class="btn-gold" @click="saldo += 100">Adicionar Saldo</button>
    </div>
</div>

<script>
    const { createApp, ref } = Vue;
    createApp({
        setup() {
            const title = ref("Painel VIP");
            const saldo = ref(1000);
            return { title, saldo };
        }
    }).mount('#app');
</script>
```

Também disponível em versão ESM:
```html
<script type="module">
    import { createApp, ref } from 'nui://vanguard_lib/vendor/vue/vue.esm-browser.prod.js';
    // ...
</script>
```

---

### 2. ⚡ HTMX 2.x
Ideal para interfaces interativas orientadas a atributos HTML simples.

```html
<script src="https://cfx-nui-vanguard_lib/vendor/htmx/htmx.min.js"></script>

<!-- Dispara callback NUI com payload JSON e substitui o conteúdo -->
<button hx-post="https://seu_recurso/comprar" 
        hx-target="#resultado" 
        hx-swap="innerHTML">
    Comprar Mochila
</button>
<div id="resultado"></div>
```

---

### 3. 🏔️ Alpine.js 3.x
Ideal para modais rápidos, toggles e painéis minimalistas com reatividade imediata.

```html
<script src="https://cfx-nui-vanguard_lib/vendor/alpine/alpine.min.js" defer></script>

<div x-data="{ aberto: false, aba: 'geral' }">
    <button @click="aberto = !aberto">Alternar Modal</button>
    <div x-show="aberto" x-transition>
        <p>Conteúdo reativo do modal...</p>
    </div>
</div>
```

---

### 4. 🗺️ Leaflet 1.9.4 (Cartografia & GPS GTA V 100% Offline)
Motor de mapas integrado com as coordenadas e satélite do GTA V (`map/atlas.js`).

```html
<link rel="stylesheet" href="https://cfx-nui-vanguard_lib/vendor/leaflet/leaflet.css">
<script src="https://cfx-nui-vanguard_lib/vendor/leaflet/leaflet.js"></script>

<div id="map" style="width: 100%; height: 500px;"></div>

<script type="module">
    import { CUSTOM_CRS, maxBounds, SateliteStyle } from 'nui://vanguard_lib/map/atlas.js';

    const map = L.map('map', {
        crs: CUSTOM_CRS,
        minZoom: 0,
        maxZoom: 5,
        maxBounds: maxBounds
    });

    SateliteStyle.addTo(map);
    map.setView([0, 0], 2);
</script>
```

---

### 5. ✨ Lucide Icons (Ícones Modernos & Leves em SVG)
Alternativa moderna, limpa e extremamente leve ao FontAwesome tradicional.

```html
<script src="https://cfx-nui-vanguard_lib/vendor/lucide/lucide.min.js"></script>

<i data-lucide="shield" style="color: var(--gold);"></i>
<i data-lucide="car"></i>
<i data-lucide="wallet"></i>

<script>
    // Inicializa todos os ícones da tela
    lucide.createIcons();
</script>
```

---

### 6. 🎨 FontAwesome 6 & Tokens Vanguard
Ícones clássicos e variáveis CSS oficiais da cidade.

```html
<!-- Cores e Tipografia Oficiais -->
<link rel="stylesheet" href="https://cfx-nui-vanguard_lib/vendor/fonts/fonts.css">
<link rel="stylesheet" href="https://cfx-nui-vanguard_lib/vendor/css/vanguard-tokens.css">

<!-- FontAwesome 6 -->
<link rel="stylesheet" href="https://cfx-nui-vanguard_lib/vendor/fontawesome/css/all.min.css">

<i class="fa-solid fa-gem" style="color: var(--gold);"></i>
```

---

### 7. 🏷️ HTM + Preact (JSX sem Build)
Para desenvolvedores que gostam da sintaxe JSX/React sem precisar de Webpack ou Vite:

```html
<script type="module">
    import { h, render } from 'nui://vanguard_lib/vendor/preact/preact.min.js';
    import htm from 'nui://vanguard_lib/vendor/htm/htm.module.js';

    const html = htm.bind(h);

    function MeuCard({ nome }) {
        return html`<div class="card p-3">Olá, ${nome}!</div>`;
    }

    render(html`<${MeuCard} nome="Jogador" />`, document.body);
</script>
```
