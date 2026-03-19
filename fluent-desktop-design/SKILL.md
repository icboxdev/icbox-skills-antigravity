---
name: Fluent Desktop Design (React/shadcn/Tailwind)
description: Enforce and generate professional desktop-application UI patterns inspired by Microsoft Fluent and Office 2010 for React + shadcn/ui + Tailwind CSS v4 projects. Covers dual-theme color palette, typography, component styling, layout dogmas, and borderless input patterns.
---

# Fluent Desktop Design System — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de estilizar qualquer componente**, consultar os tokens de design abaixo.
- **Micro-commits**: estilize um componente por vez, nunca reescreva o CSS inteiro.
- Toda nova página DEVE seguir a mesma hierarquia de layout.
- TODO frontend DEVE usar este design system como base visual.

## 2. Princípios de Design

1. **Professional Desktop** — a UI deve parecer um aplicativo de desktop profissional, não um site web.
2. **Dual-theme nativo** — Light mode como padrão para uso comercial, Dark mode confortável para uso prolongado.
3. **Inputs sem borda ao focar** — ao receber focus, inputs mudam sutilmente o background, SEM ring, SEM borda highlight.
4. **Cores maduras** — zero "AI-like" neon. Paleta sóbria e não-fatigante.
5. **Bordas sutis** — usar `border` com cor semântica (`--border`), jamais sombras fortes.
6. **Tipografia funcional** — hierarquia por peso e tamanho (Inter/system-ui como sans, JetBrains Mono para code).
7. **Micro-animações contidas** — `transition-colors 150ms`, nada flashy.

## 3. Paleta de Cores — Dogmas

### Light Mode (padrão)

| Token                | Valor     | Uso                        |
| -------------------- | --------- | -------------------------- |
| `--background`       | `#FFFFFF` | Body/page background       |
| `--foreground`       | `#333333` | Texto principal            |
| `--card`             | `#FFFFFF` | Cards, painéis             |
| `--card-foreground`  | `#333333` | Texto em cards             |
| `--primary`          | `#0078D4` | CTAs, links, accent        |
| `--primary-foreground` | `#FFFFFF` | Texto sobre primary      |
| `--secondary`        | `#F3F3F3` | Backgrounds secundários    |
| `--secondary-foreground` | `#666666` | Texto secundário       |
| `--muted`            | `#E0E0E0` | Backgrounds muted          |
| `--muted-foreground` | `#999999` | Labels, placeholders       |
| `--accent`           | `#0078D4` | Accent (= primary)         |
| `--destructive`      | `#D83B01` | Erros, exclusão            |
| `--border`           | `#E0E0E0` | Bordas de cards/inputs     |
| `--input`            | `#FFFFFF` | Background de inputs       |
| `--ring`             | `#0078D4` | Focus ring (quando usado)  |
| `--sidebar`          | `#F3F3F3` | Background sidebar         |
| `--sidebar-accent`   | `#E6F2FA` | Item ativo na sidebar      |

### Dark Mode

| Token                | Valor     | Uso                        |
| -------------------- | --------- | -------------------------- |
| `--background`       | `#1A202C` | Body/page background       |
| `--foreground`       | `#F7FAFC` | Texto principal            |
| `--card`             | `#2D3748` | Cards, painéis             |
| `--primary`          | `#4299E1` | CTAs, links, accent        |
| `--secondary`        | `#2D3748` | Backgrounds secundários    |
| `--muted`            | `#4A5568` | Backgrounds muted          |
| `--muted-foreground` | `#A0AEC0` | Labels, placeholders       |
| `--destructive`      | `#FC8181` | Erros, exclusão            |
| `--border`           | `#4A5568` | Bordas                     |
| `--input`            | `#2D3748` | Background de inputs       |
| `--sidebar`          | `#2D3748` | Background sidebar         |
| `--sidebar-accent`   | `#2A4365` | Item ativo na sidebar      |

### Chart Colors (ambos modes)

| Token       | Valor     | Significado |
| ----------- | --------- | ----------- |
| `--chart-1` | `#0078D4` | Primary     |
| `--chart-2` | `#107C10` | Success     |
| `--chart-3` | `#FFB900` | Warning     |
| `--chart-4` | `#D83B01` | Danger      |
| `--chart-5` | `#8661C5` | Info        |

## 4. Componentes — Patterns

### Inputs (REGRA CRÍTICA)

```css
/* ✅ CERTO — Input sem borda no focus */
input, textarea, select {
  @apply w-full bg-input border border-border rounded-md px-3 py-2
         text-sm text-foreground placeholder:text-muted-foreground
         focus:bg-secondary focus:border-transparent
         transition-colors outline-none;
}

/* ❌ ERRADO — ring/borda ao focar */
input:focus {
  @apply ring-2 ring-primary border-primary;  /* PROIBIDO */
}
```

### Cards

```html
<!-- ✅ CERTO — card profissional -->
<div class="bg-card border border-border rounded-lg p-6">
  <h3 class="text-sm font-semibold text-card-foreground">Título</h3>
  <p class="text-[13px] text-muted-foreground mt-1">Descrição</p>
</div>

<!-- ❌ ERRADO — glassmorphism, sombras -->
<div class="bg-white/10 backdrop-blur shadow-xl rounded-2xl">
```

### Botões

```html
<!-- Primary -->
<button class="bg-primary text-primary-foreground text-sm font-medium
               px-4 py-2 rounded-md hover:opacity-90 transition-opacity">
  Salvar
</button>

<!-- Secondary / Ghost -->
<button class="bg-secondary text-secondary-foreground text-sm
               px-4 py-2 rounded-md hover:bg-muted transition-colors">
  Cancelar
</button>

<!-- Destructive -->
<button class="bg-destructive/10 text-destructive text-sm
               px-4 py-2 rounded-md hover:bg-destructive/20 transition-colors">
  Excluir
</button>
```

### Sidebar

```html
<!-- Sidebar fixa, estilo Office -->
<aside class="w-[260px] bg-sidebar border-r border-sidebar-border h-screen">
  <nav>
    <a class="flex items-center gap-3 px-4 py-2.5 text-sm text-sidebar-foreground
              hover:bg-sidebar-accent hover:text-sidebar-accent-foreground
              rounded-md transition-colors">
      <IconComponent class="w-4 h-4" />
      Menu Item
    </a>
  </nav>
</aside>
```

### DataTables

```html
<!-- Table header — subtle, profissional -->
<thead class="bg-secondary text-xs font-medium text-muted-foreground uppercase tracking-wider">
  <tr>
    <th class="px-4 py-3 text-left">Coluna</th>
  </tr>
</thead>
<tbody class="divide-y divide-border">
  <tr class="hover:bg-secondary/50 transition-colors">
    <td class="px-4 py-3 text-sm text-foreground">Dados</td>
  </tr>
</tbody>
```

## 5. Layout

- **Sidebar fixa** (240-280px) com `bg-sidebar` e `border-r border-sidebar-border`.
- **Conteúdo principal** com `max-w-7xl mx-auto px-6 py-6`.
- **Headers de seção**: `text-xs uppercase tracking-wider font-medium text-muted-foreground`.
- **Page headers**: `text-xl font-semibold text-foreground` + descrição em `text-sm text-muted-foreground`.
- **Espaçamento**: padding interno `p-6` em cards, `gap-6` entre seções.

## 6. shadcn/ui — Configuração CSS

Todo projeto DEVE usar CSS variables no `:root` e `.dark`, seguindo o padrão shadcn:

```css
:root {
  --primary: #0078D4;
  --primary-foreground: #FFFFFF;
  --background: #FFFFFF;
  --foreground: #333333;
  --card: #FFFFFF;
  --card-foreground: #333333;
  --secondary: #F3F3F3;
  --secondary-foreground: #666666;
  --muted: #E0E0E0;
  --muted-foreground: #999999;
  --destructive: #D83B01;
  --destructive-foreground: #FFFFFF;
  --border: #E0E0E0;
  --input: #FFFFFF;
  --ring: #0078D4;
  --sidebar: #F3F3F3;
  --sidebar-accent: #E6F2FA;
  --radius: 0.5rem;
}

.dark {
  --primary: #4299E1;
  --primary-foreground: #1A202C;
  --background: #1A202C;
  --foreground: #F7FAFC;
  --card: #2D3748;
  --card-foreground: #F7FAFC;
  --secondary: #2D3748;
  --secondary-foreground: #CBD5E0;
  --muted: #4A5568;
  --muted-foreground: #A0AEC0;
  --destructive: #FC8181;
  --destructive-foreground: #1A202C;
  --border: #4A5568;
  --input: #2D3748;
  --ring: #4299E1;
  --sidebar: #2D3748;
  --sidebar-accent: #2A4365;
}
```

## 7. Anti-Patterns (PROIBIDOS)

- ❌ **Glassmorphism** (`backdrop-blur`, `bg-white/10`) — usar surface sólidas.
- ❌ **Sombras fortes** (`shadow-lg`, `shadow-xl`) — usar bordas sutis.
- ❌ **Gradientes accent** — fundo sólido, sempre.
- ❌ **Focus ring em inputs** — input muda bg ao focar, sem ring.
- ❌ **Neon/saturação** — cores desaturadas e profissionais.
- ❌ **Animated gradients** — sem animações em backgrounds.
- ❌ **rounded-full** em containers — usar `rounded-lg` / `rounded-md`.
- ❌ **Font sizes grandes** pra corpo — manter `text-sm` / `text-[13px]` como padrão.
- ❌ **Dark-first** — Light mode é o padrão. Dark mode é alternativa.

## 8. Tipografia

| Elemento      | Size       | Weight | Class                                    |
| ------------- | ---------- | ------ | ---------------------------------------- |
| Page title    | 20px       | 600    | `text-xl font-semibold`                  |
| Section title | 14px       | 600    | `text-sm font-semibold`                  |
| Body text     | 14px       | 400    | `text-sm`                                |
| Caption       | 13px       | 400    | `text-[13px]`                            |
| Label         | 12px       | 500    | `text-xs font-medium`                    |
| Section label | 11px upper | 500    | `text-[11px] uppercase tracking-wider font-medium` |
| Code/mono     | 13px       | 400    | `font-mono text-[13px]`                  |
