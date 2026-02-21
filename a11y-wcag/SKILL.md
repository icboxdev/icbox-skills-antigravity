---
name: Web Acessibilidade (a11y)
description: Validate, enforce, and generate accessible web interfaces following WCAG 2.2 AA standards. Covers keyboard navigation, semantic HTML, ARIA, color contrast, focus management, and screen reader compatibility.
---

# Acessibilidade Web (WCAG 2.2) — Diretrizes Irrenunciáveis

## 1. Zero-Trust & Limites de Contexto

- **Acessibilidade não é opcional**. Todo código gerado DEVE ser acessível por padrão.
- Não existe "adicionar a11y depois". Implemente junto com o componente.
- Faça **micro-commits**: corrija um componente por vez emitindo atualizações incrementais.

## 2. Teclado — Acesso Completo

### 2.1 Todo elemento interativo acessível via Tab

```html
<!-- ✅ CERTO — botão nativo, focável, ativável com Enter/Space -->
<button type="button" onclick="handleAction()">Confirmar</button>

<!-- ❌ ERRADO — div não-focável, sem keyboard support -->
<div class="btn" onclick="handleAction()">Confirmar</div>
```

### 2.2 Focus indicators SEMPRE visíveis

```css
/* ✅ CERTO — focus ring visível e consistente */
:focus-visible {
  outline: 2px solid var(--color-accent);
  outline-offset: 2px;
}

/* ❌ ERRADO — remover outline (inacessível) */
*:focus {
  outline: none;
}
```

### 2.3 Focus trap em modals/drawers

```tsx
// ✅ CERTO — trap focus dentro do modal
// Usar DialogPrimitive do Radix, PrimeVue Dialog, ou react-focus-lock
<Dialog.Root>
  <Dialog.Trigger asChild>
    <Button>Abrir</Button>
  </Dialog.Trigger>
  <Dialog.Content>
    {/* Focus automaticamente preso aqui */}
    <Dialog.Close />
  </Dialog.Content>
</Dialog.Root>

// ❌ ERRADO — modal sem focus trap (Tab escapa para background)
```

## 3. Semântica HTML

```html
<!-- ✅ CERTO — landmarks e heading hierarchy -->
<header role="banner">
  <nav aria-label="Menu principal">...</nav>
</header>
<main>
  <h1>Título da Página</h1>
  <!-- UM h1 por página -->
  <section aria-labelledby="sec-users">
    <h2 id="sec-users">Usuários</h2>
  </section>
</main>
<footer role="contentinfo">...</footer>

<!-- ❌ ERRADO — div soup -->
<div class="header">
  <div class="nav">...</div>
</div>
<div class="main">
  <div class="title">Título</div>
  <!-- Sem semântica -->
</div>
```

## 4. ARIA — Usar Apenas Quando Necessário

### 4.1 Primeira regra do ARIA: não use ARIA se HTML nativo resolve

```html
<!-- ✅ CERTO — HTML nativo (checkbox) -->
<label>
  <input type="checkbox" checked />
  Aceito os termos
</label>

<!-- ❌ ERRADO — ARIA no lugar de HTML nativo -->
<div role="checkbox" aria-checked="true" tabindex="0">Aceito os termos</div>
```

### 4.2 Live regions para conteúdo dinâmico

```html
<!-- ✅ CERTO — anunciar atualizações para screen readers -->
<div aria-live="polite" aria-atomic="true">3 resultados encontrados</div>

<!-- Para erros urgentes -->
<div role="alert">Erro: email inválido</div>
```

## 5. Contraste e Cor

| Elemento                         | Ratio Mínimo (AA)         |
| -------------------------------- | ------------------------- |
| Texto normal (<18px)             | **4.5:1**                 |
| Texto grande (≥18px bold, ≥24px) | **3:1**                   |
| Componentes UI (bordas, ícones)  | **3:1**                   |
| Focus indicators                 | **3:1** contra adjacentes |

- **Nunca usar cor como único indicador**. Adicionar ícone/texto/borda.

```tsx
// ✅ CERTO — erro com cor + ícone + texto
<span className="text-destructive flex items-center gap-1">
  <AlertCircle size={16} /> Campo obrigatório
</span>

// ❌ ERRADO — apenas cor vermelha (daltônicos não veem)
<span style={{ color: 'red' }}>Campo obrigatório</span>
```

## 6. Formulários

```html
<!-- ✅ CERTO — label associado + erro descritivo -->
<div>
  <label for="email">Email</label>
  <input
    id="email"
    type="email"
    aria-describedby="email-error"
    aria-invalid="true"
    required
  />
  <p id="email-error" role="alert">Formato de email inválido</p>
</div>

<!-- ❌ ERRADO — input sem label, erro sem associação -->
<input type="email" placeholder="Email" />
<span class="error">Inválido</span>
```

## 7. Target Size

- Mínimo: **24×24px** (WCAG 2.2 AA).
- Ideal: **44×44px** (Apple HIG / touch devices).
- Manter **8px+ de espaçamento** entre alvos adjacentes.

## 8. Checklist de Verificação

- [ ] Tab order correto em toda a página
- [ ] Focus visible em todos os elementos interativos
- [ ] Contraste ≥ 4.5:1 para texto, ≥ 3:1 para UI
- [ ] Todas as imagens com `alt` descritivo (ou `alt=""` para decorativas)
- [ ] Formulários com `<label>` associado e erros com `aria-describedby`
- [ ] Modals com focus trap e `Escape` para fechar
- [ ] Conteúdo dinâmico com `aria-live`
- [ ] Testar com screen reader (NVDA, VoiceOver)
- [ ] Testar navegação completa apenas com teclado
