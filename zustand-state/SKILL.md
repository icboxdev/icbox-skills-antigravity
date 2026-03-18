---
name: Zustand State Management
description: Validate, generate, and optimize Zustand stores for React TypeScript applications. Enforces typed stores, slice pattern, persist middleware, devtools integration, selector optimization, and separation of UI vs server state.
---

# Zustand — Diretrizes Sênior (v5+)

## 1. Princípio Zero: Zustand é para Client State

Zustand gerencia **client/UI state** (auth, sidebar, modals, theme). **Server state** (dados da API) pertence ao TanStack Query. NUNCA misture.

- **Skill complementar**: Leia `react-shadcn` e `tanstack-query` junto.
- **Stores pequenos**: 1 store por domínio (auth, ui, websocket). NUNCA um mega-store.
- **TypeScript estrito**: Todo store DEVE ter interface tipada. Zero `any`.

## 2. Store Básico — Padrão Obrigatório

```typescript
// CERTO: Store tipado com actions separadas
import { create } from 'zustand'

interface AuthState {
  user: User | null
  token: string | null
  isAuthenticated: boolean
}

interface AuthActions {
  setUser: (user: User, token: string) => void
  logout: () => void
}

export const useAuthStore = create<AuthState & AuthActions>((set) => ({
  // State
  user: null,
  token: null,
  isAuthenticated: false,

  // Actions
  setUser: (user, token) => set({
    user,
    token,
    isAuthenticated: true,
  }),

  logout: () => set({
    user: null,
    token: null,
    isAuthenticated: false,
  }),
}))

// ERRADO: Store sem tipagem
const useStore = create((set) => ({
  user: null,
  setUser: (user) => set({ user }),
}))
```

## 3. Selectors — Evitar Re-renders

```typescript
// CERTO: Selector granular (re-render apenas quando `user` muda)
const user = useAuthStore((state) => state.user)
const isAuthenticated = useAuthStore((state) => state.isAuthenticated)

// CERTO: Selector para múltiplos valores com shallow compare
import { useShallow } from 'zustand/react/shallow'

const { user, token } = useAuthStore(
  useShallow((state) => ({
    user: state.user,
    token: state.token,
  }))
)

// ERRADO: Pegar o store inteiro (re-render em toda mudança)
const store = useAuthStore()
```

## 4. Persist Middleware

```typescript
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

export const useAuthStore = create<AuthState & AuthActions>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      isAuthenticated: false,
      setUser: (user, token) => set({ user, token, isAuthenticated: true }),
      logout: () => set({ user: null, token: null, isAuthenticated: false }),
    }),
    {
      name: 'icbox-auth',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        token: state.token,
        // NÃO persistir user completo — refetch no mount
      }),
    }
  )
)
```

## 5. Devtools Middleware

```typescript
import { devtools, persist } from 'zustand/middleware'

export const useUIStore = create<UIState & UIActions>()(
  devtools(
    persist(
      (set) => ({
        sidebarOpen: true,
        toggleSidebar: () => set(
          (state) => ({ sidebarOpen: !state.sidebarOpen }),
          false,
          'toggleSidebar' // Nome da action no devtools
        ),
      }),
      { name: 'icbox-ui' }
    ),
    { name: 'UIStore' }
  )
)
```

## 6. Stores do ICBox CRM

```typescript
// stores/auth.ts       — user, token, login, logout, isAuthenticated
// stores/ui.ts         — sidebar, theme, modals, commandPalette
// stores/websocket.ts  — connection, events, onlineUsers
// stores/tenant.ts     — workspace config, plan, modules, limits
```

### WebSocket Store

```typescript
interface WebSocketState {
  socket: WebSocket | null
  connected: boolean
  onlineUsers: Set<string>
}

interface WebSocketActions {
  connect: (token: string) => void
  disconnect: () => void
  addOnlineUser: (userId: string) => void
  removeOnlineUser: (userId: string) => void
}

export const useWebSocketStore = create<WebSocketState & WebSocketActions>((set, get) => ({
  socket: null,
  connected: false,
  onlineUsers: new Set(),

  connect: (token) => {
    const ws = new WebSocket(`${WS_URL}?token=${token}`)
    ws.onopen = () => set({ connected: true })
    ws.onclose = () => set({ connected: false, socket: null })
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data)
      // Dispatch to TanStack Query invalidation
    }
    set({ socket: ws })
  },

  disconnect: () => {
    get().socket?.close()
    set({ socket: null, connected: false })
  },

  addOnlineUser: (userId) => set((state) => ({
    onlineUsers: new Set([...state.onlineUsers, userId])
  })),

  removeOnlineUser: (userId) => set((state) => {
    const next = new Set(state.onlineUsers)
    next.delete(userId)
    return { onlineUsers: next }
  }),
}))
```

## 7. Acessar Store Fora de Componentes

```typescript
// CERTO: getState() para interceptors Axios
import { useAuthStore } from '@/stores/auth'

api.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Auto-logout em 401
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      useAuthStore.getState().logout()
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)
```

## Constraints

- ❌ NUNCA armazene server state no Zustand — use TanStack Query
- ❌ NUNCA pegue o store inteiro — use selectors granulares
- ❌ NUNCA mute state diretamente — sempre via `set()`
- ❌ NUNCA crie mega-stores — máximo 1 store por domínio
- ❌ NUNCA persista dados sensíveis (tokens completos) sem encryption
