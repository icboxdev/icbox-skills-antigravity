---
name: Fluent Desktop Design (React/shadcn/Tailwind)
description: Enforce and generate professional desktop-application UI patterns inspired by Microsoft Fluent and Office 2010 for React + shadcn/ui + Tailwind CSS v4 projects. Covers dual-theme color palette, Segoe UI typography, Ribbon configuration, Backstage view, layout dogmas, and borderless input patterns.
---

# Fluent Desktop Design System — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de estilizar qualquer componente**, consultar os tokens de design abaixo e as especificações da era Office 2010.
- **Micro-commits**: estilize um componente por vez, nunca reescreva o CSS inteiro.
- Toda nova página DEVE seguir a mesma hierarquia de layout (Ribbon topo, Sidebar, ou Backstage).
- TODO frontend de produtividade DEVE usar este design system como base visual.

---

## 2. Princípios de Design (Enterprise Desktop)

1. **Professional Desktop** — a UI deve parecer um aplicativo de desktop profissional, não um site web "trendy". Alta densidade de informação, contraste sóbrio.
2. **Dual-theme nativo** — Light mode como padrão absoluto para uso comercial (estilo Office), Dark mode como opção confortável para uso prolongado.
3. **Office 2010 Aesthetics** — interface limpa e utilitária, pré-Flat Design (Metro), com uso de blocos sólidos sem sombras difusas.
4. **Inputs sem borda ao focar** — ao receber focus, inputs mudam sutilmente o background, SEM ring expansivo, SEM borda highlight forte (foco sutil via cor de fundo).
5. **Cores maduras** — zero "AI-like" neon. Paleta sóbria e não-fatigante (Azul, Prata, Preto).
6. **Micro-animações contidas** — durações curtas (`150ms`), nada flashy, sem ease-in/out prolongados. Mudanças snappys.

---

## 3. Especificações Visuais Office 2010

### 3.1 Tipografia (Segoe UI)

O design desktop da Microsoft exige o uso restrito de tipografia para garantir legibilidade corporativa.

- **Fonte Primária**: `Segoe UI`, `System UI`, `Inter` (como fallback sans). Nunca usar fontes arredondadas ou altamente geométricas.
- **Leitura Neutra**: sem serifas, aberta, clara.

| Elemento      | Size       | Weight | Class |
| ------------- | ---------- | ------ | ----- |
| Ribbon Tab    | 12px       | 400    | `text-xs uppercase tracking-tight` |
| Group Label   | 11px       | 500    | `text-[11px] uppercase tracking-wider text-muted-foreground` |
| Page Title    | 24px       | 400    | `text-2xl font-normal tracking-tight` |
| Body text     | 14px       | 400    | `text-sm leading-relaxed text-foreground` |
| Caption/Mono  | 13px       | 400    | `text-[13px] font-mono` |

### 3.2 Paleta de Cores (Themes Office 2010)

O framework de interface suporta 3 pilares de cor inspirados no Office:

**1. Silver Theme (Padrão corporativo, neutro e de alto contraste):**
- Backgrounds principais: `#F5F6F7`, `#FFFFFF`
- Bordas e divisores: `#D9DDE1`, `#B9C0C8`
- Texto secundário: `#7A828C`

**2. Blue Theme (O clássico Word/Outlook, enfatiza brand):**
- Acents e Headers: `#4F81BD` (Accent 1), `#1F497D` (Dark 2)
- Focus e Hover em listas: `#E6F2FA`

**3. Black Theme (Para dashboards técnicos e dark mode de alto contraste):**
- Backgrounds: `#000000`, `#1A202C`
- Cards: `#2D3748`

---

## 4. Padrões de Layout Arquitetural

### 4.1 The Ribbon UI
Inspirado na revolução do Office 2010, o Ribbon substitui menus tradicionais por grupos funcionais.

```html
<!-- ✅ CERTO — Ribbon Tab UI -->
<header class="w-full bg-secondary border-b border-border">
  <!-- Tabs Row -->
  <nav class="flex px-2 pt-2 gap-1 border-b border-border/50">
    <button class="px-4 py-1.5 text-xs text-secondary-foreground bg-background rounded-t border-t border-x border-border z-10 -mb-px">Home</button>
    <button class="px-4 py-1.5 text-xs text-muted-foreground hover:bg-muted hover:text-foreground transition-colors rounded-t">Insert</button>
  </nav>
  
  <!-- Ribbon Content Row -->
  <div class="flex p-2 gap-4 bg-background min-h-[92px]">
    <!-- Command Group -->
    <div class="flex flex-col items-center gap-1 pr-4 border-r border-border">
      <div class="flex gap-1">
        <button class="flex flex-col items-center p-2 hover:bg-muted rounded text-xs">
          <IconSave class="w-6 h-6 mb-1 text-primary" />
          Save
        </button>
      </div>
      <span class="text-[11px] text-muted-foreground">File</span>
    </div>
  </div>
</header>
```

### 4.2 The "Backstage View" (Menu Arquivo)
Para operações de nível de arquivo/configurações (print, save as, app settings). Toma a tela cheia.

```html
<!-- ✅ CERTO — Backstage View (Tela Inteira) -->
<div class="fixed inset-0 z-50 bg-background flex">
  <!-- Coluna da Esquerda: Cor Brand (ex: Azul Word, Verde Excel) -->
  <aside class="w-[250px] bg-[#4F81BD] text-primary-foreground h-full py-4 flex flex-col gap-1">
    <button class="w-full text-left px-6 py-3 text-sm flex items-center gap-3">
      <IconArrowLeft /> Return
    </button>
    <div class="h-px bg-primary-foreground/20 my-2 mx-4"></div>
    <button class="w-full text-left px-6 py-2.5 text-sm font-medium bg-primary-foreground/20">Info</button>
    <button class="w-full text-left px-6 py-2.5 text-sm font-medium hover:bg-primary-foreground/10">Save As</button>
    <button class="w-full text-left px-6 py-2.5 text-sm font-medium hover:bg-primary-foreground/10">Options</button>
  </aside>
  
  <!-- Painel Principal de Configurações -->
  <main class="flex-1 p-10 overflow-y-auto">
    <h1 class="text-3xl font-light text-foreground mb-8">Informações do Documento</h1>
    <!-- Opções -->
  </main>
</div>
```

---

## 5. Componentes Base (Inputs, Cards, Buttons)

### 5.1 Inputs (REGRA CRÍTICA - Focus)

O input de desktop corporativo não deve "gritar" ou afetar o grid ao focar.

```css
/* ✅ CERTO — Input sem borda focus expansiva, apenas mudança de background */
input, textarea, select {
  @apply w-full bg-input border border-border rounded-sm px-3 py-1.5
         text-[13px] text-foreground placeholder:text-muted-foreground
         focus:bg-secondary focus:border-border
         transition-colors outline-none ring-0 focus:ring-0;
}

/* ❌ ERRADO — Ring highlight nativo ou Tailwind excessivo */
input:focus {
  @apply ring-2 ring-primary border-primary;  /* PROIBIDO em Fluent Desktop */
}
```

### 5.2 Botões (Utilitários)

```html
<!-- Primary -->
<button class="bg-[#4F81BD] text-white text-[13px]
               px-4 py-1.5 rounded-sm hover:brightness-110 transition-all border border-[#1F497D]">
  Salvar
</button>

<!-- Secondary / Ghost (Silver) -->
<button class="bg-[#F5F6F7] text-foreground text-[13px] border border-[#B9C0C8]
               px-4 py-1.5 rounded-sm hover:bg-[#D9DDE1] transition-colors">
  Cancelar
</button>
```

### 5.3 DataTables & Grids

```html
<!-- Table header — subtle, prata corporativo -->
<thead class="bg-[#F5F6F7] text-[11px] font-medium text-[#7A828C] uppercase tracking-wider border-b border-[#B9C0C8]">
  <tr>
    <th class="px-4 py-2 border-r border-[#D9DDE1] text-left">Nome da Entidade</th>
  </tr>
</thead>
<tbody class="divide-y divide-[#D9DDE1] bg-background">
  <tr class="hover:bg-[#E6F2FA] transition-colors"> <!-- Azul selecão do office -->
    <td class="px-4 py-2 text-[13px] text-foreground border-r border-[#D9DDE1]">Dado</td>
  </tr>
</tbody>
```

---

## 6. Configuração shadcn/ui CSS (Silver Padrão)

Todo projeto DEVE usar CSS variables baseando-se no Silver Theme de alto contraste, mas aceitando dark mode.

```css
@theme {
  --color-primary: #4F81BD;
  --color-primary-foreground: #FFFFFF;
  --color-background: #FFFFFF;
  --color-foreground: #111111;
  --color-card: #FFFFFF;
  --color-card-foreground: #111111;
  --color-secondary: #F5F6F7;
  --color-secondary-foreground: #333333;
  --color-muted: #D9DDE1;
  --color-muted-foreground: #7A828C;
  --color-border: #B9C0C8;
  --color-input: #FFFFFF;
  --color-sidebar: #F5F6F7;
  --color-sidebar-accent: #E6F2FA;
}

.dark {
  --color-primary: #4F81BD;
  --color-primary-foreground: #FFFFFF;
  --color-background: #000000;
  --color-foreground: #F5F6F7;
  --color-card: #1A202C;
  --color-card-foreground: #F5F6F7;
  --color-secondary: #2D3748;
  --color-secondary-foreground: #CBD5E0;
  --color-muted: #4A5568;
  --color-muted-foreground: #A0AEC0;
  --color-border: #4A5568;
  --color-input: #1A202C;
  --color-sidebar: #1A202C;
  --color-sidebar-accent: #2A4365;
}
```

*(Nota: a sintaxe acima deve ser adaptada à forma como o Tailwind v4 expõe as variáveis de tema ou CSS nativo. Em `shadcn` padrão, aplica-se sem prefixo `--color-` no bloco `@layer base`)*

---

## 7. Anti-Patterns (PROIBIDOS)

- ❌ **Drop Shadows intensas** (`shadow-lg`, `shadow-xl`) — a interface corporativa baseia-se em bordas finas sólidas.
- ❌ **Glassmorphism / Acrílico pesado** (`backdrop-blur`) — evitar. A estética 2010 foca em blocks opacos; a estética moderna Fluent usa mica de forma muito cirúrgica atrás do app, não em botões.
- ❌ **Animações "Bouncy"** — zero efeitos elásticos. Transições devem ser lineares ou fast-out/linear-in (150ms).
- ❌ **Border Radius excessivo** — `rounded-full` ou `rounded-xl` é proibido para containers e botões; usar `rounded-sm` ou `rounded`.
- ❌ **Espaçamento colossal (Padding)** — websites modernos de marketing usam gaps enormes. Dashboards usam interfaces compactadas (`py-1.5`, `py-2`) para densidade de dados.
- ❌ **Focus Rings brilhantes** no hover ou focus de data inputs.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.
