---
name: Vue/PrimeVue Frontend
description: Architect, style, and orchestrate Vue 3 + PrimeVue (Unstyled/PT) applications with Tailwind CSS. Follows Composition API, structural reactivity constraints, and specific UI component rendering heuristics.
---

# Vue 3 + PrimeVue — Diretrizes de Engenharia

## 1. Princípio Zero: Memória de Contexto "Zero-Trust"

- **Externalização Visual**: Ao ser solicitado para desenvolver Layouts ou páginas críticas, crie ou modifique instâncias de projeto em `src/views/` testando o visual _antes_ de seguir. Sempre quebre Componentes complexos em sub-arquivos menores do que refatorar um `.vue` de 1000 linhas, estourando o "Thinking Token Limit" do modelo.
- **Validação Antecipada de Slots**: Nunca "adivinhe" a API de Slots antigos do PrimeVue. Sempre gere código em versão atualizada (`v4+`).

## 2. Reatividade Estrita (Vue 3 Composition API)

A principal causa de perda de "Frames" no Vue é reatividade mal compreendida. A partir de agora:

- **Banimento do `reactive` genérico**: O uso livre de `reactive({})` para agrupamentos genéricos de estado e formulários profundos adiciona overhead e perde referência na desestruturação. Centralize `ref()` sempre que possível.
- **`shallowRef` para Dados API**: Nunca injete "grandes listas JSON" num `ref` comum. Se você fizer o fetch de 1000 linhas para uma tabela, use `shallowRef()`.

### Few-Shot: Reatividade de Dados de Lista Em Tabela

```html
<!-- CERTO (Performance Massiva para tabelas grandes) -->
<script setup lang="ts">
  import { shallowRef, onMounted } from "vue";

  const products = shallowRef<Product[]>([]);

  onMounted(async () => {
    products.value = await fetchProducts();
  });
</script>

<!-- ERRADO (Toda a árvore do objeto é sobrecarregada c/ proxies deep) -->
<script setup lang="ts">
  import { ref } from "vue";
  const products = ref<Product[]>([]);
</script>
```

## 3. PrimeVue Unstyled Mode e Pass-Through (PT)

As aplicações de elite modernas nunca usam o modo de temas antigos do PrimeVue, e sim o modo **Unstyled**.

- O modelo a ser arquitetado exige Tailwind CSS global injetado primariamente via propriedade `pt` (Pass-Through).
- Não escreva tag `<style scoped>` no componente `Vue` tentando sobrescrever cor de classe fixa (`.p-button`). Faça injeção.

### Few-Shot: Pass-Through Local (Tailwind UI)

```html
<!-- CERTO -->
<template>
  <button
    label="Confirmar"
    :pt="{
      root: { class: 'bg-indigo-600 hover:bg-indigo-700 text-white rounded-md px-4 py-2' },
      icon: { class: 'text-white' }
    }"
  />
</template>

<!-- ERRADO (Tentando usar classe de pacote Styled) -->
<template>
  <button class="p-button-danger" label="Remover" />
</template>
```

## 4. Gerenciamento de Estado de Frontend (Pinia)

Nunca crie "GlobalStore". Se houver uma Store, ela deve ser uma "Setup Store". Cuidado para não armazenar cache do Backend dentro do Pinia duplicando estado. O Pinia lida com "Client State" (modais abertos, usuário logado).

### Few-Shot: "Setup-Store" Certa vs Errada

```typescript
// CERTO (Estilo Composition)
export const useAuthStore = defineStore("auth", () => {
  const user = ref<User | null>(null);
  const isAuthenticated = computed(() => !!user.value);

  function login(data: User) {
    /* ... */
  }

  return { user, isAuthenticated, login };
});

// ERRADO (Estilo Options)
export const useAuthStore = defineStore("auth", {
  state: () => ({ user: null }),
  getters: { isAuthenticated: (state) => !!state.user },
});
```

## Resumo Operacional para Criação

Quando solicitado para criar UI usando _Vue 3 + PrimeVue_:

1. Utilize sempre `script setup lang="ts"`.
2. Programe os componentes visando a arquitetura Tailwind-Unstyled via `pt`.
3. Garanta uso de `shallowRef` em arrays de massa.

## 5. Regra Defensiva (Vue DOM & Error Parsing)

**NUNCA** utilize expressões ternárias (`{{ condicao ? 'Texto A' : 'Texto B extreeeeemamente longo...' }}`) na UI do Template Vue para interpretar blocos inteiros, parágrafos ou Strings maiores que 4 palavras.  
O limite de largura de linha de Auto-Formatters como ESLint/Prettier (printWidth: 80-120) quebra strings literais (`'`) no meio do valor, causando um fatal Error "Unterminated string literal".

### Few-Shot: Renderização Condicional Limpa e Nativa

```html
<!-- CERTO (Blindado contra Formattings Breaks usando v-if/v-else) -->
<h3>
  <span v-if="isEditing">Alterar Assinatura do Tenant Corrente</span>
  <span v-else>Vincular Plano Base para o Novo Tenant Autogerado</span>
</h3>

<!-- ERRADO (String será repartida e quebrará o compilador!) -->
<h3>
  {{ isEditing ? 'Alterar Assinatura do Tenant Corrente' : 'Vincular Plano Base
  para o Novo Tenant Autogerado' }}
</h3>
```
