---
name: Supabase Design (Vue/PrimeVue/Tailwind)
description: Enforce and generate dark-first, minimal UI patterns inspired by Supabase Dashboard for Vue 3 + PrimeVue + Tailwind CSS projects. Covers color palette, typography, component styling, and layout dogmas.
---

# Supabase Design System — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de criar um componente**, consultar os tokens de design em `resources/tokens.md` (cores, spacing, tipografia).
- Faça **micro-commits**: estilize um componente por vez.
- Para tabelas de tokens completas e PT overrides, consulte `resources/` desta skill.

## 2. Princípios de Design

1. **Dark-first** — dark mode é o padrão, light mode é adaptação.
2. **Minimal** — menos é mais. Cada pixel deve ter propósito.
3. **Bordas sutis** — usar `border-default` (`hsl(var(--border-default))`) ao invés de sombras.
4. **Uma cor de destaque** — `brand-500` (verde Supabase) para CTAs e estados ativos.
5. **Tipografia funcional** — tamanhos menores que o padrão, hierarquia por peso.
6. **Espaçamento generoso** — padding interno alto, margens consistentes.

## 3. Paleta — Dogmas

```css
/* ✅ CERTO — usar tokens semânticos, nunca cores brutas */
.card {
  background-color: hsl(var(--background-surface-100));
  border: 1px solid hsl(var(--border-default));
  color: hsl(var(--foreground-default));
}

.card-title {
  color: hsl(var(--foreground-default));
  font-weight: 500;
}

.card-description {
  color: hsl(var(--foreground-muted));
  font-size: 0.8125rem;
}

/* ❌ ERRADO — cores hardcoded */
.card {
  background-color: #1c1c1c;
  border: 1px solid #333;
  color: white;
}
```

### Tokens Semânticos Essenciais

| Token                      | Dark      | Uso                     |
| -------------------------- | --------- | ----------------------- |
| `--background-default`     | `#171717` | Body/page background    |
| `--background-surface-100` | `#1c1c1c` | Cards, panels           |
| `--background-surface-200` | `#232323` | Nested containers       |
| `--background-overlay`     | `#2a2a2a` | Popovers, dropdowns     |
| `--foreground-default`     | `#ededed` | Texto principal         |
| `--foreground-muted`       | `#a1a1a1` | Texto secundário        |
| `--foreground-subtle`      | `#6b6b6b` | Labels, placeholders    |
| `--border-default`         | `#2e2e2e` | Bordas de cards         |
| `--border-strong`          | `#3e3e3e` | Separadores             |
| `--brand-500`              | `#3ecf8e` | Accent (verde Supabase) |
| `--destructive-500`        | `#ef4444` | Erros, exclusão         |
| `--warning-500`            | `#f59e0b` | Avisos                  |

> Tabela completa em `resources/tokens.md`.

## 4. Componentes — Patterns

### Cards

```html
<!-- ✅ CERTO — card Supabase-style -->
<div class="bg-surface-100 border border-default rounded-lg p-6">
  <h3 class="text-sm font-medium text-foreground">Título</h3>
  <p class="text-[13px] text-foreground-muted mt-1">Descrição</p>
</div>
```

### Botões

```html
<!-- Primary (brand) -->
<button
  class="bg-brand-500 hover:bg-brand-600 text-white text-sm font-medium
               px-4 py-2 rounded-md transition-colors"
>
  Criar projeto
</button>

<!-- Secondary (ghost) -->
<button
  class="bg-transparent hover:bg-surface-200 text-foreground-muted
               text-sm px-4 py-2 rounded-md border border-default transition-colors"
>
  Cancelar
</button>

<!-- Destructive -->
<button
  class="bg-destructive-500/10 hover:bg-destructive-500/20
               text-destructive-500 text-sm px-4 py-2 rounded-md transition-colors"
>
  Excluir
</button>
```

### Forms

```html
<!-- Input Supabase-style -->
<div>
  <label class="text-xs font-medium text-foreground-muted mb-1.5 block">
    Nome do projeto
  </label>
  <input
    class="w-full bg-surface-200 border border-default rounded-md px-3 py-2
                text-sm text-foreground placeholder:text-foreground-subtle
                focus:ring-1 focus:ring-brand-500 focus:border-brand-500
                transition-colors"
  />
</div>
```

## 5. Layout

- Sidebar fixa (240-280px) com `bg-surface-100` e `border-r border-default`.
- Conteúdo principal com `max-w-5xl mx-auto px-6 py-8`.
- Headers de seção: `text-xs uppercase tracking-wider text-foreground-subtle`.

## 6. PrimeVue — Pass-Through para Supabase Style

```typescript
// ✅ CERTO — PT override para alinhar com design system
app.use(PrimeVue, {
  unstyled: true,
  pt: {
    button: {
      root: {
        class:
          "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium transition-colors",
      },
    },
    inputtext: {
      root: {
        class:
          "w-full bg-surface-200 border border-default rounded-md px-3 py-2 text-sm text-foreground focus:ring-1 focus:ring-brand-500",
      },
    },
    card: {
      root: { class: "bg-surface-100 border border-default rounded-lg" },
      body: { class: "p-6" },
      title: { class: "text-sm font-medium text-foreground" },
    },
  },
});
```

## 7. Anti-Patterns

- ❌ Sombras grandes (`shadow-lg`, `shadow-xl`) — Supabase usa bordas, não sombras.
- ❌ Cores saturadas no dark mode — usar tons desaturados.
- ❌ Font sizes grandes (`text-lg`, `text-xl`) para texto corrido — manter `text-sm` / `text-[13px]`.
- ❌ `rounded-full` em cards/containers — usar `rounded-lg` / `rounded-md`.
- ❌ Gradientes chamativos — fundo sólido ou gradiente extremamente sutil.
