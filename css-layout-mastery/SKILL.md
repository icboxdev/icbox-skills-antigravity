---
name: CSS Layout Mastery
description: Validate, debug, and generate CSS layout patterns enforcing full-height containers, Flexbox/Grid overflow chains, min-h-0 propagation, sticky headers, container queries, and responsive scroll areas.
---

# CSS Layout Mastery — Full-Height, Overflow & Container Queries

## 1. Propósito

Resolver definitivamente os bugs mais frequentes de layout CSS em SPAs e dashboards: listas que não preenchem a tela, overflow quebrado, scroll que não funciona em containers flex, e headers que não fixam. Esta skill garante que o agente nunca mais gere layouts com altura incorreta.

## 2. Dogmas Arquiteturais

### A Cadeia de Altura (Height Chain)

Para que um elemento atinja `100vh` ou preencha seu container, **toda a cadeia de ancestrais** deve propagar altura. Se QUALQUER ancestral quebrar a cadeia, o filho não expande.

**SEMPRE verifique a cadeia completa**: `html → body → #root → layout → page → component`.

### Regra do `min-h-0`

Flex items têm `min-height: auto` por padrão — isso IMPEDE que encolham abaixo do conteúdo intrínseco. Para containers flex com scroll interno, `min-h-0` é **obrigatório** no flex item que deve encolher.

**NUNCA** crie um container flex vertical com scroll interno sem `min-h-0` no item scrollável.

### Regra do Overflow

`overflow: auto` ou `overflow: hidden` só funciona quando o elemento tem altura definida (explícita ou via flex). Container sem altura = overflow inútil.

**NUNCA** aplique `overflow-auto` sem garantir que o elemento tem altura restrita.

### Sticky Headers

`position: sticky` exige que o nearest scrollable ancestor tenha overflow definido. Se o pai for `overflow: visible` (padrão), sticky não funciona.

**SEMPRE** garanta que o `overflow` do container scrollável está configurado antes de usar sticky.

## 3. Patterns Essenciais

### 3.1 Full-Height Page Layout (Dashboard)

```css
/* CERTO — Cadeia completa de altura */
html, body { height: 100%; margin: 0; }
#root { display: flex; flex-direction: column; min-height: 100vh; }

.layout { display: flex; flex: 1; min-height: 0; }
.sidebar { width: 256px; flex-shrink: 0; }
.main-content {
  flex: 1;
  min-height: 0;      /* ← Permite encolher */
  display: flex;
  flex-direction: column;
  overflow: hidden;    /* ← Contém os filhos */
}

.page-wrapper {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;       /* ← Propaga para tabela */
  gap: 1rem;
}

.data-table-container {
  flex: 1;
  min-height: 0;       /* ← Permite scroll */
  overflow: auto;       /* ← Scroll aqui */
}
```

```css
/* ERRADO — Cadeia quebrada, scroll não funciona */
.main-content {
  /* Sem min-height: 0 — flex item não encolhe */
  overflow: auto;   /* Não funciona sem altura restrita */
}

.page-wrapper {
  height: 100%;     /* 100% de quê? Pai não tem altura explícita */
}

.data-table-container {
  overflow: auto;   /* Pai não tem min-h-0, não encolhe, scroll inútil */
}
```

### 3.2 Tailwind Equivalentes

```html
<!-- CERTO — Full-height com Tailwind -->
<div class="flex flex-1 flex-col min-h-0">           <!-- layout content -->
  <div class="flex flex-1 flex-col gap-4">            <!-- page wrapper -->
    <header class="shrink-0">PageHeader</header>      <!-- não encolhe -->
    <div class="flex-1 min-h-0 overflow-auto">        <!-- scrollable area -->
      <table>...</table>
    </div>
  </div>
</div>
```

```html
<!-- ERRADO — min-h-0 ausente, scroll quebrado -->
<div class="flex flex-col flex-1">
  <div class="space-y-6">                              <!-- space-y não propaga flex -->
    <div class="overflow-auto">                        <!-- sem altura restrita -->
      <table>...</table>
    </div>
  </div>
</div>
```

### 3.3 Sticky Table Header

```html
<!-- CERTO — Sticky header em tabela com scroll -->
<div class="flex-1 min-h-0 overflow-auto">
  <table class="w-full">
    <thead class="sticky top-0 z-10 bg-background">
      <tr>...</tr>
    </thead>
    <tbody>...</tbody>
  </table>
</div>
```

```html
<!-- ERRADO — Sticky não funciona, nenhum ancestor tem overflow -->
<div class="flex-1">
  <table>
    <thead class="sticky top-0">  <!-- Sem overflow no pai = sticky inútil -->
      <tr>...</tr>
    </thead>
  </table>
</div>
```

### 3.4 Container Queries

```css
/* CERTO — Component responsivo ao container, não ao viewport */
.card-grid {
  container-type: inline-size;
  container-name: card-grid;
}

@container card-grid (min-width: 640px) {
  .card { grid-template-columns: repeat(2, 1fr); }
}

@container card-grid (min-width: 1024px) {
  .card { grid-template-columns: repeat(3, 1fr); }
}
```

```html
<!-- Tailwind v4 container queries -->
<div class="@container">
  <div class="grid grid-cols-1 @sm:grid-cols-2 @lg:grid-cols-3">
    ...
  </div>
</div>
```

## 4. Checklist de Auditoria de Layout

Ao auditar uma página, verificar nesta ordem:

1. **Cadeia de altura**: html → body → root → layout → page → component — todos flex column?
2. **`min-h-0`**: Presente em TODOS os flex items que contêm scroll ou filhos flex?
3. **`flex-1`**: Presente no elemento que deve expandir?
4. **`overflow-auto`**: Presente apenas em elementos com altura restrita?
5. **`shrink-0`**: Headers e footers marcados como shrink-0?
6. **`sticky`**: Nearest scrollable ancestor tem overflow definido?
7. **Wrapper padrão**: Todas as pages usam `flex flex-1 flex-col gap-4`?

## 5. Anti-Patterns PROIBIDOS

| Anti-Pattern | Por quê | Correção |
|-------------|---------|----------|
| `height: 100%` sem pai com altura | 100% de 0 = 0 | Use `flex-1` na cadeia flex |
| `space-y-*` como wrapper de página | Não propaga flex | Use `flex flex-col gap-*` |
| `overflow-auto` sem altura restrita | Scroll nunca ativa | Adicione `min-h-0` + `flex-1` |
| `max-h-screen` dentro de flex layout | Ignora a cadeia flex | Use `flex-1 min-h-0` |
| `vh` units em mobile | Address bar muda 100vh | Use `dvh` ou flex chain |

## 6. Zero-Trust

- **NUNCA** assumir que `overflow-auto` funciona sem verificar a cadeia de altura.
- **NUNCA** usar `space-y-*` como wrapper root de página — substituir por `flex flex-col gap-*`.
- **SEMPRE** testar layout em viewport estreito (mobile) e largo (desktop).
- **SEMPRE** verificar se sticky headers funcionam após mudanças de layout.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

