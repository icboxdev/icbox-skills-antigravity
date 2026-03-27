---
name: Tailwind CSS v4
description: Validate, migrate, and generate Tailwind CSS v4 code enforcing CSS-first configuration, @theme directive, @utility API, Oxide engine patterns, container queries, and v3-to-v4 migration strategies.
---

# Tailwind CSS v4 — @theme, @utility, Oxide Engine & Migration

## 1. Propósito

Dominar as breaking changes e novos patterns do Tailwind CSS v4, incluindo a nova configuração CSS-first via `@theme`, a API `@utility` para utilities customizadas, container queries nativas, e o processo de migração v3→v4.

## 2. Dogmas Arquiteturais

### CSS-First Configuration

**NUNCA** usar `tailwind.config.js` no Tailwind v4. Toda customização via `@theme` no CSS.

### @import Único

**NUNCA** usar `@tailwind base; @tailwind components; @tailwind utilities;` — substituir por `@import "tailwindcss";`.

### Content Detection Automática

**NUNCA** configurar `content: [...]` manualmente — v4 detecta automaticamente os templates.

### Browser Support

Tailwind v4 requer browsers modernos (Safari 16.4+, Chrome 111+, Firefox 128+). **NUNCA** usar v4 se precisa suportar browsers legados.

## 3. Patterns Essenciais

### 3.1 Setup Básico v4

```css
/* CERTO — Tailwind v4 */
@import "tailwindcss";

@theme {
  --color-brand: #38bdf8;
  --color-brand-dark: #0284c7;
  --font-sans: "Inter", sans-serif;
  --font-mono: "JetBrains Mono", monospace;
  --radius-lg: 0.75rem;
  --shadow-card: 0 1px 3px 0 rgb(0 0 0 / 0.1);
}
```

```css
/* ERRADO — Tailwind v3 (deprecated em v4) */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* tailwind.config.js */
module.exports = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: { brand: "#38bdf8" },
    },
  },
};
```

### 3.2 @theme — Design Tokens em CSS

```css
/* CERTO — Tokens como CSS variables nativas */
@theme {
  /* Colors */
  --color-background: #09090b;
  --color-foreground: #fafafa;
  --color-primary: #38bdf8;
  --color-destructive: #ef4444;

  /* Spacing customizado */
  --spacing-sidebar: 256px;

  /* Breakpoints (renomeáveis) */
  --breakpoint-sm: 640px;
  --breakpoint-md: 768px;
  --breakpoint-lg: 1024px;

  /* Animations */
  --animate-fade-in: fade-in 0.3s ease-out;
}

@keyframes fade-in {
  from { opacity: 0; transform: translateY(-4px); }
  to { opacity: 1; transform: translateY(0); }
}
```

```html
<!-- Usando os tokens em classes -->
<div class="bg-background text-foreground">
  <button class="bg-primary animate-fade-in">Click</button>
</div>

<!-- Acessando via CSS variable nativa -->
<div style="color: var(--color-primary)">Dinâmico</div>
```

### 3.3 @utility — Utilities Customizadas

```css
/* CERTO — Utility customizada com @utility */
@utility glass {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(12px);
  border: 1px solid rgba(255, 255, 255, 0.1);
}

@utility scrollbar-thin {
  scrollbar-width: thin;
  scrollbar-color: var(--color-muted) transparent;
}

@utility text-balance {
  text-wrap: balance;
}
```

```html
<!-- Usar como qualquer utility -->
<div class="glass rounded-lg p-4">Glassmorphism card</div>
<div class="overflow-auto scrollbar-thin">Lista scrollável</div>
```

```css
/* ERRADO — Layer utilities (v3 pattern, deprecated) */
@layer utilities {
  .glass {
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(12px);
  }
}
```

### 3.4 Container Queries (Built-in)

```html
<!-- CERTO — Container queries nativas no v4 -->
<div class="@container">
  <div class="grid grid-cols-1 @sm:grid-cols-2 @lg:grid-cols-3 gap-4">
    <div class="p-4 @sm:p-6">
      Responsivo ao container, não ao viewport
    </div>
  </div>
</div>

<!-- Container nomeado -->
<div class="@container/sidebar">
  <nav class="@sm/sidebar:flex-row flex-col">...</nav>
</div>
```

```html
<!-- ERRADO — Media query para componente que vive em diferentes containers -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">
  <!-- md/lg se referem ao VIEWPORT, não ao container do componente -->
</div>
```

### 3.5 Dark Mode com v4

```css
/* Tokens light e dark no mesmo @theme */
@theme {
  --color-background: #ffffff;
  --color-foreground: #09090b;
}

@theme dark {
  --color-background: #09090b;
  --color-foreground: #fafafa;
}
```

### 3.6 Novos Utilities v4

```html
<!-- 3D Transforms -->
<div class="rotate-x-12 rotate-y-6 perspective-800">3D card</div>

<!-- Gradients avançados -->
<div class="bg-linear-to-r from-sky-400 to-cyan-300">Linear</div>
<div class="bg-radial from-primary to-transparent">Radial</div>
<div class="bg-conic from-red-500 via-yellow-500 to-green-500">Conic</div>

<!-- @starting-style (enter/exit animations sem JS) -->
<dialog class="starting:opacity-0 starting:scale-95 opacity-100 scale-100 transition-all">
  Modal com animação de entrada
</dialog>

<!-- not-* variant -->
<button class="not-disabled:hover:bg-primary">Hover só se não disabled</button>

<!-- Inset shadow e ring -->
<input class="inset-shadow-sm inset-ring inset-ring-border" />

<!-- Field sizing -->
<textarea class="field-sizing-content">Auto resize</textarea>
```

## 4. Migração v3 → v4

### Tool Automático

```bash
# Ferramenta oficial de migração
npx @tailwindcss/upgrade
```

### Checklist Manual

| v3 | v4 | Ação |
|----|-----|------|
| `@tailwind base/components/utilities` | `@import "tailwindcss"` | Substituir |
| `tailwind.config.js` | `@theme {}` no CSS | Migrar tokens |
| `content: [...]` | Detecção automática | Remover |
| `@layer utilities { .foo {} }` | `@utility foo {}` | Migrar |
| PostCSS `tailwindcss` plugin | `@tailwindcss/postcss` | Atualizar pacote |
| `decoration-slice/clone` | `box-decoration-slice/clone` | Renomear |
| `ring` (3px default) | `ring` (1px default, currentColor) | Verificar visual |
| `border-*` (gray default) | `border-*` (currentColor default) | Verificar visual |

### PostCSS v4

```javascript
// CERTO — postcss.config.js para v4
module.exports = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

```javascript
// ERRADO — PostCSS config v3
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},  // Não necessário no v4
  },
};
```

## 5. Performance (Oxide Engine)

- Build inicial: **3-10x mais rápido** que v3
- Rebuild incremental: **até 40x mais rápido**
- CSS output: **~25% menor**
- **NUNCA** precisa de `purge` ou `content` config — detecção automática

## 6. Zero-Trust

- **NUNCA** misturar config v3 (`tailwind.config.js`) com v4 (`@theme`).
- **NUNCA** usar `autoprefixer` separado — v4 já inclui.
- **NUNCA** assumir que classes v3 funcionam identicamente em v4 (ring, border, divide mudaram defaults).
- **SEMPRE** rodar `npx @tailwindcss/upgrade` antes de migrar manualmente.
- **SEMPRE** testar visualmente após migração — defaults de ring/border/divide mudaram.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

