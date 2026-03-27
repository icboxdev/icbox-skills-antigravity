---
name: TanStack Query (React Query v5)
description: Validate, generate, and optimize TanStack Query v5 for React TypeScript. Enforces queryKey conventions, typed hooks, mutation patterns, cache invalidation, optimistic updates, infinite queries, prefetching, and integration with Zustand and Axios.
---

# TanStack Query — Diretrizes Sênior (v5+)

## 1. Princípio Zero: Server State ≠ Client State

TanStack Query gerencia **server state** (dados da API). Client state (sidebar, modals, auth) pertence ao Zustand. NUNCA misture.

- **Skill complementar**: Leia `zustand-state` e `react-shadcn` junto.
- **queryKey é sacred**: Toda query DEVE ter key tipada e hierárquica.
- **staleTime > 0**: NUNCA deixe staleTime em 0 para tudo — defina por domínio.

## 2. Setup — QueryClient

```typescript
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ReactQueryDevtools } from '@tanstack/react-query-devtools'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,        // 30s padrão
      gcTime: 300_000,          // 5min garbage collect
      retry: 1,                 // 1 retry em falha
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
    },
  },
})

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  )
}
```

## 3. Query Keys — Convenção

```typescript
// CERTO: Factory de query keys tipadas
export const contactKeys = {
  all: ['contacts'] as const,
  lists: () => [...contactKeys.all, 'list'] as const,
  list: (filters: ContactFilters) => [...contactKeys.lists(), filters] as const,
  details: () => [...contactKeys.all, 'detail'] as const,
  detail: (id: string) => [...contactKeys.details(), id] as const,
  timeline: (id: string) => [...contactKeys.detail(id), 'timeline'] as const,
}

// Permite invalidação granular:
// queryClient.invalidateQueries({ queryKey: contactKeys.all })     → tudo
// queryClient.invalidateQueries({ queryKey: contactKeys.lists() }) → só listas
// queryClient.invalidateQueries({ queryKey: contactKeys.detail('123') }) → 1 detalhe

// ERRADO: Keys hardcoded e sem tipagem
useQuery({ queryKey: ['contacts', id] })
```

## 4. Custom Hooks — Padrão

```typescript
// hooks/useContacts.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { contactKeys } from '@/lib/queryKeys'

// GET — Lista
export function useContacts(filters: ContactFilters) {
  return useQuery({
    queryKey: contactKeys.list(filters),
    queryFn: () => api.get<PaginatedResponse<Contact>>('/contacts', { params: filters }),
    select: (data) => data.data,
  })
}

// GET — Detalhe
export function useContact(id: string) {
  return useQuery({
    queryKey: contactKeys.detail(id),
    queryFn: () => api.get<Contact>(`/contacts/${id}`),
    select: (data) => data.data,
    enabled: !!id,  // Não buscar se id é vazio
  })
}

// POST — Criar
export function useCreateContact() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (data: CreateContactDto) =>
      api.post<Contact>('/contacts', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: contactKeys.lists() })
    },
  })
}

// PUT — Atualizar
export function useUpdateContact() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: UpdateContactDto }) =>
      api.put<Contact>(`/contacts/${id}`, data),
    onSuccess: (_, { id }) => {
      queryClient.invalidateQueries({ queryKey: contactKeys.detail(id) })
      queryClient.invalidateQueries({ queryKey: contactKeys.lists() })
    },
  })
}

// DELETE — Soft delete
export function useDeleteContact() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) => api.delete(`/contacts/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: contactKeys.lists() })
    },
  })
}
```

## 5. Optimistic Updates

```typescript
export function useMoveDeal() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ dealId, toStage }: MoveDealDto) =>
      api.put(`/deals/${dealId}/move`, { stage_id: toStage }),

    onMutate: async ({ dealId, toStage }) => {
      // Cancel ongoing queries
      await queryClient.cancelQueries({ queryKey: dealKeys.all })

      // Snapshot previous state
      const previous = queryClient.getQueryData(dealKeys.lists())

      // Optimistic update
      queryClient.setQueryData(dealKeys.lists(), (old: Deal[] | undefined) =>
        old?.map((deal) =>
          deal.id === dealId ? { ...deal, stage_id: toStage } : deal
        )
      )

      return { previous }
    },

    onError: (_, __, context) => {
      // Rollback on error
      if (context?.previous) {
        queryClient.setQueryData(dealKeys.lists(), context.previous)
      }
    },

    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: dealKeys.lists() })
    },
  })
}
```

## 6. Infinite Scrolling

```typescript
export function useInboxMessages(conversationId: string) {
  return useInfiniteQuery({
    queryKey: ['inbox', conversationId, 'messages'],
    queryFn: ({ pageParam }) =>
      api.get(`/inbox/conversations/${conversationId}/messages`, {
        params: { cursor: pageParam, limit: 50 },
      }),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.data.meta.next_cursor,
    select: (data) => ({
      pages: data.pages.flatMap((page) => page.data.data),
      pageParams: data.pageParams,
    }),
  })
}
```

## 7. Prefetching

```typescript
// Prefetch no hover de um link
function ContactRow({ contact }: { contact: Contact }) {
  const queryClient = useQueryClient()

  const handleHover = () => {
    queryClient.prefetchQuery({
      queryKey: contactKeys.detail(contact.id),
      queryFn: () => api.get(`/contacts/${contact.id}`),
      staleTime: 60_000,
    })
  }

  return (
    <tr onMouseEnter={handleHover}>
      <td>{contact.name}</td>
    </tr>
  )
}
```

## 8. WebSocket → Query Invalidation

```typescript
// No WebSocket handler (Zustand)
ws.onmessage = (event) => {
  const data = JSON.parse(event.data)

  switch (data.type) {
    case 'deal:moved':
      queryClient.invalidateQueries({ queryKey: dealKeys.all })
      break
    case 'inbox:message':
      queryClient.invalidateQueries({
        queryKey: ['inbox', data.conversation_id, 'messages']
      })
      break
    case 'notification:new':
      queryClient.invalidateQueries({ queryKey: ['notifications'] })
      break
  }
}
```

## 9. Error Handling Global

```typescript
const queryClient = new QueryClient({
  defaultOptions: {
    mutations: {
      onError: (error: unknown) => {
        if (error instanceof AxiosError) {
          const message = error.response?.data?.error?.message || 'Erro inesperado'
          toast.error(message)
        }
      },
    },
  },
})
```

## Constraints

- ❌ NUNCA armazene UI state no TanStack Query — use Zustand
- ❌ NUNCA use queryKey strings hardcoded — use factory pattern
- ❌ NUNCA esqueça invalidação após mutation
- ❌ NUNCA use enabled: true com dados que dependem de params — use `!!param`
- ❌ NUNCA faça fetch no useEffect — sempre useQuery
- ❌ NUNCA use staleTime: 0 globalmente — defina por domínio

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

