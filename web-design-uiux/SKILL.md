---
name: Web Design & UI/UX Engineering
description: Architect, validate, and generate web interfaces enforcing modern layout systems (CSS Grid, Flexbox, Container Queries), design token architecture, typography systems, color theory, responsive patterns, micro-animations, accessibility (WCAG 2.2 AA), and conversion-focused visual hierarchy.
---

# Web Design & UI/UX Engineering — Diretrizes Sênior

## 1. Princípio Zero

Esta skill transforma o agente em um **Web Designer Sênior / Design Engineer** que entrega interfaces premium, acessíveis e de alta conversão. Todo design deve comunicar **valor**, guiar o **olhar**, e converter a **ação**.

Se o design é "bonito mas confuso", ele falhou. Se é "funcional mas feio", ele também falhou.

## 2. Os 8 Pilares do Web Design Moderno

| Pilar              | Descrição                              | Entregável                      |
| ------------------ | -------------------------------------- | ------------------------------- |
| **Layout & Grid**  | CSS Grid + Flexbox + Container Queries | Layouts responsivos e modulares |
| **Tipografia**     | Type scale, variable fonts, fluid type | Sistema tipográfico hierárquico |
| **Cor & Tema**     | Design tokens, dark/light, paletas     | Sistema de cores coerente       |
| **Espaçamento**    | Spacing scale (4px base), rhythm       | Consistência visual             |
| **Animação**       | Micro-interactions, GPU-only, motion   | Feedback visual e fluidez       |
| **Responsividade** | Mobile-first, breakpoints, fluid       | Adaptação a qualquer viewort    |
| **Acessibilidade** | WCAG 2.2 AA, ARIA, focus, contrast     | Inclusão real                   |
| **Conversão**      | Visual hierarchy, CTA, whitespace      | Guiar o olhar → ação            |

## 3. Dogmas Inegociáveis

### Layout & Grid System

- SEMPRE use **CSS Grid** para layout macro (page structure, _grids_ 2D).
- SEMPRE use **Flexbox** para layout micro (alignment dentro de componentes).
- SEMPRE use **Container Queries** para componentes verdadeiramente modulares.
- SEMPRE defina grid com `minmax()` e `auto-fit`/`auto-fill` para responsividade intrínseca.
- NUNCA use `float` para layout — Grid e Flexbox cobrem 100% dos casos.
- NUNCA use pixels fixos para larguras de containers — `max-width` + `margin: auto`.

```css
/* CERTO: Grid responsivo intrínseco */
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: var(--space-4);
}

/* CERTO: Container Query para componente modular */
.card-container {
  container-type: inline-size;
  container-name: card;
}

@container card (min-width: 400px) {
  .card {
    flex-direction: row;
  }
}

/* ERRADO: Layout com float */
.sidebar {
  float: left;
  width: 250px;
}
.content {
  margin-left: 270px;
}
```

### Sistema Tipográfico

- SEMPRE defina uma **type scale** matemática (ex: 1.25 ratio — Minor Third).
- SEMPRE use **variable fonts** quando disponíveis — reduzem HTTP requests e file size.
- SEMPRE use `clamp()` para **fluid typography** — elimina breakpoints de font-size.
- SEMPRE limite a **2 famílias tipográficas** por projeto (heading + body).
- SEMPRE garanta **line-height mínimo de 1.5** para body text (WCAG).
- NUNCA use unidades `px` para font-size — use `rem` ou `clamp()`.
- NUNCA use mais de 4 pesos (weights) de uma mesma font — impacta performance.

```css
/* CERTO: Type Scale com clamp() */
:root {
  --text-xs: clamp(0.64rem, 0.6rem + 0.18vw, 0.75rem);
  --text-sm: clamp(0.8rem, 0.75rem + 0.23vw, 0.875rem);
  --text-base: clamp(1rem, 0.93rem + 0.29vw, 1rem);
  --text-lg: clamp(1.125rem, 1.04rem + 0.36vw, 1.25rem);
  --text-xl: clamp(1.25rem, 1.15rem + 0.45vw, 1.5rem);
  --text-2xl: clamp(1.5rem, 1.35rem + 0.65vw, 2rem);
  --text-3xl: clamp(1.875rem, 1.65rem + 0.95vw, 2.5rem);
  --text-4xl: clamp(2.25rem, 1.9rem + 1.5vw, 3.5rem);

  --font-heading: "Inter Variable", system-ui, sans-serif;
  --font-body: "Inter Variable", system-ui, sans-serif;

  --leading-tight: 1.2;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;
}

h1 {
  font-size: var(--text-4xl);
  line-height: var(--leading-tight);
}
p {
  font-size: var(--text-base);
  line-height: var(--leading-normal);
}

/* ERRADO: Font sizes em pixels fixos */
h1 {
  font-size: 48px;
}
p {
  font-size: 16px;
  line-height: 1.2;
}
```

### Sistema de Cores & Design Tokens

- SEMPRE defina cores como **design tokens** (CSS custom properties), não valores hardcoded.
- SEMPRE organize tokens em 3 camadas: **primitives** → **semantic** → **component**.
- SEMPRE garanta **dark mode** desde o início — não como afterthought.
- SEMPRE valide contraste com ferramentas (mínimo **4.5:1** para texto, **3:1** para UI).
- SEMPRE use **HSL** para definir cores — facilita variações (lighten/darken via lightness).
- NUNCA use cores sem significado semântico — `--color-success` > `--color-green-500`.
- NUNCA defina cores diretamente em componentes.

```css
/* CERTO: Design Tokens em 3 camadas */

/* Layer 1: Primitives (raw palette) */
:root {
  --green-50: hsl(145, 80%, 96%);
  --green-500: hsl(145, 63%, 42%);
  --green-600: hsl(145, 63%, 35%);
  --gray-50: hsl(220, 15%, 97%);
  --gray-900: hsl(220, 15%, 10%);
}

/* Layer 2: Semantic (meaning) */
:root {
  --color-bg: var(--gray-50);
  --color-fg: var(--gray-900);
  --color-brand: var(--green-500);
  --color-brand-hover: var(--green-600);
  --color-success: var(--green-500);
  --color-surface: white;
  --color-border: hsl(220, 15%, 88%);
}

/* Layer 2: Dark theme override */
[data-theme="dark"] {
  --color-bg: var(--gray-900);
  --color-fg: var(--gray-50);
  --color-surface: hsl(220, 15%, 15%);
  --color-border: hsl(220, 15%, 25%);
}

/* Layer 3: Component token */
.btn-primary {
  background: var(--color-brand);
  color: white;
}
.btn-primary:hover {
  background: var(--color-brand-hover);
}

/* ERRADO: Cor hardcoded no componente */
.btn-primary {
  background: #22c55e;
  color: white;
}
.btn-primary:hover {
  background: #16a34a;
}
```

### Spacing Scale (Espaçamento)

- SEMPRE use uma escala baseada em **4px** (ou 8px para sistemas mais amplos).
- SEMPRE defina como tokens: `--space-1: 0.25rem` até `--space-16: 4rem`.
- SEMPRE respeite **rhythm vertical** — espaçamento consistente entre seções.
- NUNCA use valores arbitrários: `margin-top: 13px` → use `var(--space-3)`.

```css
/* CERTO: Spacing Scale (base 4px = 0.25rem) */
:root {
  --space-0: 0;
  --space-1: 0.25rem; /* 4px */
  --space-2: 0.5rem; /* 8px */
  --space-3: 0.75rem; /* 12px */
  --space-4: 1rem; /* 16px */
  --space-5: 1.25rem; /* 20px */
  --space-6: 1.5rem; /* 24px */
  --space-8: 2rem; /* 32px */
  --space-10: 2.5rem; /* 40px */
  --space-12: 3rem; /* 48px */
  --space-16: 4rem; /* 64px */
  --space-20: 5rem; /* 80px */
  --space-24: 6rem; /* 96px */
}

/* ERRADO: Valores aleatórios */
.card {
  padding: 17px;
  margin-bottom: 23px;
}
```

### Micro-Animações & Motion

- SEMPRE anime apenas propriedades **GPU-accelerated**: `transform` e `opacity`.
- SEMPRE use `transition` para mudanças de estado, `@keyframes` para loops.
- SEMPRE respeite `prefers-reduced-motion` — desabilite animações complexas.
- SEMPRE use `will-change` com moderação (apenas em elementos que de fato animam).
- SEMPRE duração entre **150ms** (feedback rápido) e **500ms** (transições de layout).
- NUNCA anime `width`, `height`, `top`, `left`, `margin`, `padding` — causam reflow.
- NUNCA use animação como decoração sem propósito funcional.

```css
/* CERTO: Micro-animation GPU-only */
.card {
  transition:
    transform 200ms ease,
    opacity 200ms ease,
    box-shadow 200ms ease;
}
.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 24px hsl(0 0% 0% / 0.08);
}

/* CERTO: Respeita reduced-motion */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}

/* ERRADO: Anima propriedades que causam reflow */
.card:hover {
  width: 110%;
  margin-top: -5px;
  padding: 20px;
}
```

### Responsividade — Mobile First

- SEMPRE comece pelo **mobile** e escale com `min-width` media queries.
- SEMPRE use breakpoints **semânticos**, não device-based.
- SEMPRE use `clamp()`, `min()`, `max()` para fluid sizing.
- SEMPRE use Container Queries para componentes reutilizáveis.
- SEMPRE teste em viewports reais: 320px, 375px, 768px, 1024px, 1440px.
- SEMPRE use dynamic viewport units (`dvh`, `svh`) para mobile browsers.
- NUNCA esconda conteúdo importante em mobile — reorganize, não oculte.

```css
/* CERTO: Mobile-first breakpoints semânticos */
:root {
  /* Breakpoints como referência (usar em media queries) */
  /* sm: 640px, md: 768px, lg: 1024px, xl: 1280px, 2xl: 1536px */
}

.hero {
  padding: var(--space-8) var(--space-4);
}

@media (min-width: 768px) {
  .hero {
    padding: var(--space-16) var(--space-8);
  }
}

@media (min-width: 1024px) {
  .hero {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-12);
  }
}

/* ERRADO: Desktop-first (max-width) */
@media (max-width: 768px) {
  .hero {
    padding: 20px;
  }
}
```

### Acessibilidade — WCAG 2.2 AA

- SEMPRE garanta contraste: **4.5:1** para texto normal, **3:1** para texto grande e UI.
- SEMPRE use **HTML semântico**: `<header>`, `<main>`, `<nav>`, `<section>`, `<article>`, `<aside>`.
- SEMPRE forneça **focus visible** em todos os interativos — nunca `outline: none` sem substituto.
- SEMPRE use `:focus-visible` para focar apenas via teclado (não mouse).
- SEMPRE tenha **skip-to-content** link como primeiro elemento focável.
- SEMPRE use **aria-label** apenas quando o elemento não tem texto visível.
- SEMPRE teste com **tab navigation** completa — toda a página deve ser navegável.
- NUNCA use ARIA quando HTML nativo resolve (botão = `<button>`, não `<div role="button">`).
- NUNCA remova outline do `:focus` sem substituir por indicador visual equivalente.
- NUNCA dependa apenas de **cor** para comunicar estado (adicione ícone/texto).

```html
<!-- CERTO: Semântico + acessível -->
<header>
  <a href="#main-content" class="skip-link">Pular para conteúdo</a>
  <nav aria-label="Navegação principal">
    <ul>
      <li><a href="/">Início</a></li>
      <li><a href="/about">Sobre</a></li>
    </ul>
  </nav>
</header>
<main id="main-content">
  <h1>Página Principal</h1>
  <button type="button">
    <span class="sr-only">Fechar</span>
    <svg aria-hidden="true"><!-- icon --></svg>
  </button>
</main>

<!-- ERRADO: Div-soup sem semântica -->
<div class="header">
  <div class="nav">
    <div class="nav-item" onclick="navigate('/')">Início</div>
  </div>
</div>
<div class="main">
  <div class="title">Página Principal</div>
  <div class="btn" onclick="close()">X</div>
</div>
```

```css
/* CERTO: Focus visible elegante */
:focus-visible {
  outline: 2px solid var(--color-brand);
  outline-offset: 2px;
  border-radius: 4px;
}

/* Skip link acessível */
.skip-link {
  position: absolute;
  top: -100%;
  left: 0;
  padding: var(--space-2) var(--space-4);
  background: var(--color-brand);
  color: white;
  z-index: 999;
  transition: top 150ms ease;
}
.skip-link:focus {
  top: 0;
}

/* Screen-reader only utility */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
}

/* ERRADO: Remove outline sem substituir */
button:focus {
  outline: none;
}
```

### Hierarquia Visual & Conversão

- SEMPRE estabeleça hierarquia: **F-pattern** para conteúdo, **Z-pattern** para landing.
- SEMPRE tenha **1 CTA primário** visualmente dominante por viewport.
- SEMPRE use **whitespace** como ferramenta de design — não como "espaço vazio".
- SEMPRE contraste o CTA: cor que não aparece em nenhum outro elemento da página.
- SEMPRE posicione elementos-chave no **terço superior** da viewport (above the fold).
- NUNCA use mais de 3 pesos de hierarquia na mesma seção.
- NUNCA tenha 2 CTAs competindo visualmente no mesmo bloco.

## 4. Design Tokens — Estrutura Recomendada

```
tokens/
├── primitives/
│   ├── colors.css      /* Raw palette: --green-50, --green-500, etc. */
│   ├── typography.css   /* Font families, sizes, weights, line-heights */
│   └── spacing.css      /* --space-1 through --space-24 */
├── semantic/
│   ├── light.css        /* --color-bg, --color-fg, --color-brand, etc. */
│   ├── dark.css         /* Dark theme overrides */
│   └── motion.css       /* --duration-fast, --ease-in-out, etc. */
└── components/
    ├── button.css       /* --btn-padding, --btn-radius */
    ├── card.css         /* --card-border, --card-shadow */
    └── input.css        /* --input-border, --input-focus */
```

## 5. CSS Moderno — Técnicas Essenciais (2025)

| Técnica               | Uso                           | Suporte           |
| --------------------- | ----------------------------- | ----------------- |
| `container queries`   | Responsividade por componente | ✅ Todos browsers |
| `@layer`              | Organizar cascade             | ✅ Todos browsers |
| `:has()`              | Parent selector               | ✅ Todos browsers |
| `CSS nesting`         | Aninhar seletores nativamente | ✅ Todos browsers |
| `subgrid`             | Herdar grid do pai            | ✅ Todos browsers |
| `clamp()`             | Fluid sizing (tipo, spacing)  | ✅ Todos browsers |
| `:focus-visible`      | Focus via teclado apenas      | ✅ Todos browsers |
| `color-mix()`         | Mistura de cores em CSS       | ✅ Todos browsers |
| `dvh / svh`           | Viewport dinâmico mobile      | ✅ Todos browsers |
| `View Transitions`    | Transições entre pages/states | 🟡 Chrome/Edge    |
| `@scope`              | Escopo de estilos             | 🟡 Chrome/Edge    |
| `Scroll-driven anims` | Animações por scroll          | 🟡 Chrome/Edge    |

## 6. Performance Visual

- SEMPRE use **WebP/AVIF** para imagens — 30-50% menor que JPEG/PNG.
- SEMPRE use `loading="lazy"` em imagens below the fold.
- SEMPRE defina `width` e `height` explícitos em `<img>` para evitar CLS.
- SEMPRE use `srcset` para servir imagens responsivas.
- SEMPRE minimize CSS — remova regras não utilizadas (PurgeCSS).
- NUNCA carregue fonts que não serão usadas na page — subset fonts.
- NUNCA use imagens >200KB sem necessidade comprovada.

```html
<!-- CERTO: Imagem otimizada -->
<img
  src="hero.webp"
  srcset="hero-480.webp 480w, hero-768.webp 768w, hero-1200.webp 1200w"
  sizes="(max-width: 768px) 100vw, 50vw"
  width="1200"
  height="600"
  alt="Dashboard do ICBox mostrando progresso do projeto"
  loading="lazy"
  decoding="async"
/>

<!-- ERRADO: Imagem sem otimização -->
<img src="hero.png" alt="hero" />
```

## 7. UX Patterns Essenciais

| Pattern                        | Quando Usar                      |
| ------------------------------ | -------------------------------- |
| **Skeleton loading**           | Carregamento de dados assíncrono |
| **Toast notification**         | Feedback de ação (sucesso/erro)  |
| **Empty state**                | Lista vazia com CTA              |
| **Progressive disclosure**     | Forms complexos em steps         |
| **Infinite scroll / paginate** | Longas listas de dados           |
| **Sticky nav/CTA**             | Manter ação acessível ao scroll  |
| **Modal confirmation**         | Ações destrutivas irreversíveis  |
| **Breadcrumb**                 | Navegação hierárquica profunda   |
| **Command palette**            | Power users (Ctrl+K)             |
| **Onboarding flow**            | Primeiro acesso guiado           |

## 8. Checklist de Review de Design

- [ ] **Hierarquia clara** — Headline > subheadline > body > caption
- [ ] **CTA visível** — acima do fold, cor contrastante, texto de ação
- [ ] **Espaçamento consistente** — usa spacing scale, sem valores arbitrários
- [ ] **Cores semânticas** — tokens em 3 camadas, dark mode funciona
- [ ] **Tipografia fluid** — clamp(), rem, máximo 2 families, line-height ≥ 1.5
- [ ] **Mobile-first** — funciona em 320px, touch targets ≥ 44px
- [ ] **Acessibilidade** — contraste ≥ 4.5:1, focus visible, skip-link, ARIA correto
- [ ] **Performance** — WebP/AVIF, lazy load, dimensions explícitas, CLS < 0.1
- [ ] **Animações** — GPU-only, reduced-motion, duração 150-500ms
- [ ] **Grid/Layout** — CSS Grid + Flexbox, container queries, sem float
