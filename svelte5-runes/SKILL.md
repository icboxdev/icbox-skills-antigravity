---
name: Svelte 5 Runes Architecture
description: Validate, architect, and generate frontend code using Svelte 5 and SvelteKit. Enforces the new explicit Reactivity model using Runes ($state, $derived, $effect, $props) over legacy reactive assignments.
---

# Svelte 5 Runes Dogmas

You are a Frontend Architect expert in compiler-based reactivity. Svelte 5 fundamentally changes how reactivity works by introducing Runes. You MUST NOT use Svelte 4 legacy reactivity (`export let`, `$:`) in new codebases.

## 1. Explicit State Management ($state)
- Use `$state(initialValue)` to define reactive state. Only wrap variables that *need* to trigger DOM updates.
- `$state` works universally: inside `.svelte` files and inside raw `.js/.ts` files (replacing the need for complex custom stores in many cases).

## 2. Derived State ($derived)
- Use `$derived(expression)` to compute values based on `$state`. It calculates lazily and is glitch-free.
- NEVER mutate state inside a `$derived` calculation.

## 3. Side Effects ($effect)
- Use `$effect(() => { ... })` for synchronizing state with the DOM or external systems (like fetching data based on a state change).
- **WARNING**: `$effect` only runs in the Browser (post-SSR). It replaces both `onMount` (in many cases) and legacy `$: {}` blocks. Use it judiciously to prevent infinite loops (similar to React's `useEffect`).

## 4. Properties ($props)
- Replace `export let myProp` with `let { myProp } = $props();`.
- Use `$bindable()` if you want to allow two-way binding of a prop from a parent.

## 5. Event Handling
- Replace legacy `on:click` with modern standard `onclick`.

### ❌ ERRADO (Svelte 4 Legacy)
```svelte
<script>
  export let count = 0;
  $: double = count * 2;
</script>
<button on:click={() => count++}>{double}</button>
```

### ✅ CERTO (Svelte 5 Runes)
```svelte
<script>
  let { count = $bindable(0) } = $props();
  let double = $derived(count * 2);
</script>
<button onclick={() => count++}>{double}</button>
```

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

