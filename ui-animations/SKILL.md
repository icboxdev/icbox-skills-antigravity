---
name: Animações e UI Fluida
description: Validate, optimize, and generate UI animations enforcing GPU-accelerated properties, motion accessibility, and micro-interaction patterns with Framer Motion and CSS transitions.
---

# Animações & UI Fluida — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de animar**, definir o propósito funcional da animação (feedback, orientação, deleite).
- Faça **micro-commits**: implemente uma animação por vez, teste em dispositivos reais.
- **Animação sem propósito é ruído visual**. Se não melhora a UX, remova.

## 2. Propriedades — GPU vs CPU

### 2.1 Apenas propriedades GPU-accelerated

```css
/* ✅ CERTO — GPU-accelerated (compositing layer) */
.card {
  transition:
    transform 200ms ease-out,
    opacity 200ms ease-out;
}
.card:hover {
  transform: translateY(-4px) scale(1.02);
  opacity: 0.95;
}

/* ❌ ERRADO — layout thrashing (CPU-intensive) */
.card:hover {
  top: -4px; /* Causa reflow! */
  width: 102%; /* Causa reflow! */
  margin-left: 2px; /* Causa reflow! */
}
```

**Regra inegociável**: animar APENAS `transform` e `opacity`. Qualquer outra propriedade causa layout recalculation (jank).

### 2.2 `will-change` com parcimônia

```css
/* ✅ CERTO — apenas quando necessário, removido depois */
.animating {
  will-change: transform;
}

/* ❌ ERRADO — will-change em tudo (desperdiça memória GPU) */
* {
  will-change: transform, opacity;
}
```

## 3. Durações e Easing

| Tipo                                  | Duração   | Easing                     |
| ------------------------------------- | --------- | -------------------------- |
| Micro-feedback (hover, press)         | 100-150ms | `ease-out`                 |
| Transições de estado (toggle, expand) | 200-300ms | `ease-in-out`              |
| Entrada de elemento (fade-in, slide)  | 300-500ms | `ease-out` / `spring`      |
| Saída de elemento                     | 150-250ms | `ease-in`                  |
| Animações complexas (page transition) | 400-600ms | `cubic-bezier` customizado |

> **Nunca ultrapassar 600ms**. Animações longas irritam o usuário.

## 4. Acessibilidade — `prefers-reduced-motion`

```css
/* ✅ CERTO — SEMPRE respeitar a preferência do usuário */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

```tsx
// ✅ CERTO — Framer Motion com hook de acessibilidade
import { useReducedMotion } from "framer-motion";

function Card() {
  const prefersReduced = useReducedMotion();

  return (
    <motion.div
      initial={{ opacity: 0, y: prefersReduced ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: prefersReduced ? 0 : 0.3 }}
    />
  );
}

// ❌ ERRADO — ignorar prefers-reduced-motion
<motion.div animate={{ x: 100, rotate: 360 }} />;
```

## 5. Padrões por Ferramenta

### CSS/Tailwind — estados simples

```css
/* Hover, focus, toggle — CSS puro é suficiente */
.btn {
  transition:
    transform 150ms ease-out,
    box-shadow 150ms ease-out;
}
.btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgb(0 0 0 / 0.15);
}
.btn:active {
  transform: translateY(0) scale(0.98);
}
```

### Framer Motion — orquestração complexa

```tsx
// Layout animations (shared layout)
<motion.div layoutId="card" />

// Stagger children (lista animada)
<motion.ul
  initial="hidden"
  animate="visible"
  variants={{
    visible: { transition: { staggerChildren: 0.05 } },
  }}
>
  {items.map((item) => (
    <motion.li
      key={item.id}
      variants={{
        hidden: { opacity: 0, y: 10 },
        visible: { opacity: 1, y: 0 },
      }}
    />
  ))}
</motion.ul>
```

### GSAP — Scroll e timeline

Usar apenas quando Framer Motion não suporta (scroll-triggered, SVG morph, canvas).

## 6. Anti-Patterns

- ❌ Animar `height: auto` → usar `max-height` com valor definido ou Framer `animate={{ height: 'auto' }}`.
- ❌ `setInterval` para animações → usar `requestAnimationFrame` ou libs declarativas.
- ❌ Animações em listas sem `key` estável → causa flickering.
- ❌ Parallax pesado em mobile → janky, drenar bateria.
- ❌ Transições em `display: none/block` → usar `opacity` + `pointer-events`.
