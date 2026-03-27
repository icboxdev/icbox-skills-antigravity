---
name: SaaS Frontend Architecture
description: Architect, validate, and generate multi-tenant SaaS frontend applications using React or Vue. Enforces tenant context management, dynamic routing, RBAC UI patterns, performance optimization, and strict separation of global vs. server state.
---

# SaaS Frontend Architecture — Diretrizes Senior+

## 1. Princípio Zero: Isolamento e Contexto Global

Em aplicações multi-tenant, o frontend deve ter absoluta certeza de qual tenant está ativo a qualquer momento. Falhar no gerenciamento de estado do tenant pode vazar dados de um cliente para outro.

## 2. Gerenciamento de Estado (Global vs. Server)

Nunca misture estado de interface (UI) ou autenticação/tenant com dados oxigenados via API. 

- **Global State (Zustand/Pinia):** APENAS para `Tenant Context`, `User Profile`, `Theme/UI State` (sidebar, modals abertos).
- **Server State (TanStack Query):** PARA TODOS os dados cacheados vindos da API (listas, detalhes de entidades). O `tenant_id` DEVE sempre fazer parte da `queryKey`.

```typescript
// CERTO (React Query)
const { data } = useQuery({
  queryKey: ['users', currentTenantId], // Tenant ID no cache origin!
  queryFn: () => api.getUsers(currentTenantId)
})

// ERRADO
const { data } = useQuery({
  queryKey: ['users'], // Risco de vazar cache cross-tenant ao trocar de conta
  queryFn: () => api.getUsers()
})
```

## 3. Dynamic Theming e White-labeling

Projetos SaaS frequentemente requerem temas por tenant.

- Use **CSS Variables** ativadas via Javascript na raiz (`<html>` ou `<body>`) para injetar cores e fontes carregadas do banco.
- Evite gerar classes atômicas dinâmicas via string interpolation no Tailwind. Use as CSS variables dentro de `@theme` ou `tailwind.config.ts`.

## 4. RBAC (Role-Based Access Control) na UI

A interface deve refletir as permissões do usuário, removendo (não apenas desabilitando) rotas e botões não autorizados, aplicando "Zero-Trust" (a API sempre fará a validação real).

```tsx
// CERTO
<Can action="delete" resource="users">
  <DeleteButton userId={id} />
</Can>

// ERRADO
<DeleteButton userId={id} disabled={user.role !== 'admin'} /> 
// O botão não deve nem ser renderizado para evitar exploração de DOM.
```

## 5. Roteamento Consciente de Tenant

Sempre que possível, o `tenant_id` ou `slug` deve fazer parte da URL persistente (ex: `/b2b/[tenant_id]/dashboard`) ou do subdomínio. Isso garante que page reloads e compartilhamento de links mantenham o contexto íntegro.

## 6. Otimização Crítica (Code Splitting)

SaaS views são pesadas. Entidades grandes (Analytics, Mapas, Dashboard Builders) NÃO DEVEM fazer parte do bundle inicial.
- **Sempre utilize** `React.lazy()` ou `next/dynamic` para páginas pesadas ou modais ocultos por padrão.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

