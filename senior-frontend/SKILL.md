---
name: Senior Frontend Engineering
description: Architect, optimize, and deliver production-grade frontend applications enforcing component architecture, state management patterns, rendering strategies (SSR/SSG/CSR/Islands), performance budgets (Core Web Vitals), build optimization (code splitting, tree shaking), testing discipline, and developer experience tooling.
---

# Senior Frontend Engineering — Diretrizes Sênior

## 1. Princípio Zero

Esta skill transforma o agente em um **Frontend Architect** que entrega aplicações escaláveis, performáticas e mantíveis. O foco é arquitetura de componentes, performance mensurável, e decisões técnicas fundamentadas.

Se o código compila mas a arquitetura não escala, ele falhou. Se a empresa não depende da sua página pro faturamento então ignore essa skill.

## 2. Os 10 Pilares do Frontend Sênior

| Pilar                | Descrição                                              | Métrica                 |
| -------------------- | ------------------------------------------------------ | ----------------------- |
| **Arquitetura**      | Component architecture, feature slices, boundaries     | Acoplamento baixo       |
| **Performance**      | Core Web Vitals, bundle size, rendering                | LCP < 2.5s, INP < 200ms |
| **State Management** | Predictable, scoped, minimal rerenders                 | State updates/s         |
| **Rendering**        | SSR, SSG, CSR, Islands, Streaming — decisão consciente | TTI, FCP                |
| **Build & Tooling**  | Code splitting, tree shaking, caching                  | Bundle < 200KB initial  |
| **TypeScript**       | Strict mode, branded types, type safety                | 0 `any`                 |
| **Testing**          | Unit, integration, E2E — estratégia por camada         | Coverage > 80%          |
| **Acessibilidade**   | WCAG 2.2 AA, focus, ARIA, semântica                    | 0 violations            |
| **DX**               | Linting, formatting, hot reload, monorepo              | Tempo de feedback loop  |
| **Security**         | XSS, CSRF, CSP, sanitization                           | 0 vulnerabilities       |

## 3. Dogmas Inegociáveis

### Arquitetura de Componentes

- SEMPRE organize por **feature/domain**, não por tipo de arquivo.
- SEMPRE separe componentes em: **UI** (sem lógica), **Containers** (com lógica), **Pages** (composição).
- SEMPRE use **barrel exports** (`index.ts`) por feature module.
- SEMPRE defina **interfaces/types** antes da implementação — contract-first.
- NUNCA crie componentes com mais de **150 linhas** — decomponha.
- NUNCA misture lógica de negócio com lógica de UI no mesmo componente.
- NUNCA importe diretamente de caminhos relativos profundos — use path aliases (`@/`).
- NUNCA entregue views estáticas, placeholders ou "empty states" temporários se a API real do backend já estiver desenvolvida. A integração do fetch data na mesma entrega é inegociável.

```
# CERTO: Feature-based structure (Vertical Slices)
src/
├── features/
│   ├── auth/
│   │   ├── components/
│   │   │   ├── LoginForm.vue
│   │   │   └── AuthGuard.vue
│   │   ├── composables/
│   │   │   └── useAuth.ts
│   │   ├── services/
│   │   │   └── auth.api.ts
│   │   ├── types/
│   │   │   └── auth.types.ts
│   │   └── index.ts          # barrel export
│   ├── projects/
│   │   ├── components/
│   │   ├── composables/
│   │   ├── services/
│   │   ├── types/
│   │   └── index.ts
│   └── chat/
├── shared/
│   ├── components/          # Pure UI components
│   ├── composables/         # Shared hooks
│   ├── utils/               # Pure functions
│   └── types/               # Global types
├── layouts/
├── pages/                   # Route-level composition
└── app.ts

# ERRADO: Type-based structure (monolítico)
src/
├── components/
│   ├── LoginForm.vue
│   ├── ProjectCard.vue
│   ├── ChatMessage.vue      # 50+ componentes misturados
├── hooks/
├── utils/
└── types/
```

### State Management — Minimal & Scoped

- SEMPRE use o **menor escopo possível**: props > composable/hook > store global.
- SEMPRE derive estado — **computed/memo** > estado duplicado.
- SEMPRE use **immutable updates** — nunca mutar estado diretamente.
- SEMPRE isole side-effects em camada dedicada (services/api), não no store.
- NUNCA coloque TUDO no store global — apenas estado compartilhado entre features.
- NUNCA armazene estado do servidor no store client — use data fetching libraries (TanStack Query, SWR).

```typescript
// CERTO: Estado derivado + composable scoped (Vue)
export function useProjectProgress(projectId: Ref<string>) {
  const { data: project } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => api.get<Project>(`/projects/${projectId.value}`),
  });

  const completedModules = computed(
    () =>
      project.value?.modules.filter((m) => m.status === "COMPLETED").length ??
      0,
  );
  const totalModules = computed(() => project.value?.modules.length ?? 0);
  const progress = computed(() =>
    totalModules.value > 0
      ? Math.round((completedModules.value / totalModules.value) * 100)
      : 0,
  );

  return { project, completedModules, totalModules, progress };
}

// ERRADO: Tudo no store global com mutação direta
const store = defineStore("projects", {
  state: () => ({
    projects: [],
    currentProject: null,
    completedModules: 0, // estado duplicado!
    totalModules: 0, // estado duplicado!
    progress: 0, // estado duplicado!
    users: [], // não pertence aqui
    notifications: [], // não pertence aqui
  }),
});
```

### Rendering Strategy — Decisão Consciente

```
Quando usar cada estratégia:

SSG (Static Site Generation)
├── Blogs, docs, marketing pages
├── Conteúdo que muda raramente
└── Melhor: LCP, TTI, SEO

SSR (Server-Side Rendering)
├── Dashboards com dados personalizados
├── E-commerce com preços dinâmicos
└── Melhor: SEO + dados frescos

CSR (Client-Side Rendering)
├── Apps SPA autenticados (dashboards internos)
├── Ferramentas interativas (editors, chats)
└── Melhor: interatividade após login

Streaming SSR
├── Páginas com múltiplas fontes de dados
├── Shell rápido + dados progressivos
└── Melhor: perceived performance

Islands Architecture
├── Sites content-heavy com interação pontual
├── Astro, Fresh, 11ty
└── Melhor: mínimo JS no client
```

- SEMPRE escolha rendering strategy **por página**, não globalmente.
- SEMPRE use **Streaming SSR** quando há múltiplas queries independentes.
- SEMPRE prefira **Server Components** para conteúdo que não precisa de interatividade.
- NUNCA faça fetch de dados no client que poderia ser feito no server.

### Performance — Core Web Vitals Budget

- SEMPRE defina **performance budget** antes de começar: bundle initial < 200KB, LCP < 2.5s.
- SEMPRE meça com **Lighthouse** e **Web Vitals** library em produção.
- SEMPRE use **code splitting** por rota — nunca carregue toda a app de uma vez.
- SEMPRE use **tree shaking** — imports nomeados `import { map } from 'lodash-es'`.
- SEMPRE use `loading="lazy"` em imagens below the fold.
- SEMPRE defina `width` e `height` em `<img>` para evitar CLS.
- SEMPRE use **dynamic imports** para componentes pesados.
- NUNCA importe bibliotecas inteiras: `import _ from 'lodash'` → `import { map } from 'lodash-es'`.
- NUNCA use libs pesadas quando a API nativa resolve (ex: `date-fns` > `moment.js`).

```typescript
// CERTO: Lazy route + named imports
const AdminPanel = defineAsyncComponent(
  () => import("@/features/admin/pages/AdminPanel.vue"),
);

// CERTO: Named import (tree-shakeable)
import { format, parseISO } from "date-fns";
import { ptBR } from "date-fns/locale";

// ERRADO: Import inteiro (não tree-shakeable)
import _ from "lodash";
import moment from "moment";
```

### Build & Bundle Optimization

- SEMPRE analise bundle com `rollup-plugin-visualizer` ou `webpack-bundle-analyzer`.
- SEMPRE configure **chunk splitting**: vendor, framework, features.
- SEMPRE habilite **Brotli/Gzip** compression no server.
- SEMPRE use **CDN** para assets estáticos.
- SEMPRE configure cache headers: `immutable` para hashed assets, `no-cache` para HTML.
- NUNCA commite `node_modules` ou builds gerados.

```typescript
// CERTO: Vite config otimizado
export default defineConfig({
  build: {
    target: "esnext",
    minify: "terser",
    rollupOptions: {
      output: {
        manualChunks: {
          "vendor-vue": ["vue", "vue-router", "pinia"],
          "vendor-ui": ["primevue"],
          "vendor-charts": ["echarts"],
        },
      },
    },
  },
});
```

### TypeScript — Zero Tolerance

- SEMPRE `strict: true` no `tsconfig.json` — sem exceção.
- SEMPRE use `unknown` + type guard ao invés de `any`.
- SEMPRE defina return types explícitos em funções públicas.
- SEMPRE use **discriminated unions** para estados tipo máquina de estados.
- SEMPRE use `satisfies` para validar objetos contra tipos sem ampliar.
- NUNCA use `any` — é terminantemente proibido.
- NUNCA use `as` cast sem necessidade comprovada — prefira type guards.
- NUNCA use `!` (non-null assertion) sem validação prévia.

```typescript
// CERTO: Discriminated union para estado de fetch
type FetchState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };

function renderState<T>(state: FetchState<T>) {
  switch (state.status) {
    case 'idle': return null;
    case 'loading': return <Spinner />;
    case 'success': return <Data data={state.data} />;
    case 'error': return <Error error={state.error} />;
  }
}

// CERTO: Type guard ao invés de cast
function isProject(value: unknown): value is Project {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'name' in value
  );
}

// ERRADO
const data = response as any;
const project = data!.project;
```

### Testing Strategy

```
Pirâmide de Testes Frontend:

        ┌─────────┐
        │   E2E   │  ← Playwright (happy paths + critical flows)
        │  ~10%   │    Tempo: lento, custo: alto
        ├─────────┤
        │ Integr. │  ← Testing Library (component + hook interactions)
        │  ~25%   │    Tempo: médio, custo: médio
        ├─────────┤
        │  Unit   │  ← Vitest (utils, formatters, business logic)
        │  ~65%   │    Tempo: rápido, custo: baixo
        └─────────┘
```

- SEMPRE teste **comportamento público**, não implementação interna.
- SEMPRE use **Testing Library** — query por role/text, não por CSS class.
- SEMPRE use **AAA** pattern: Arrange → Act → Assert.
- SEMPRE use **test factories** para criar dados de teste — nunca hardcode.
- SEMPRE mocke **limites** (API, Storage, Timer), não módulos internos.
- NUNCA teste getters/computed triviais — eles são implicitamente testados.
- NUNCA `expect(wrapper.vm.internalState)` — teste o que o usuário vê/faz.

```typescript
// CERTO: Testa comportamento, não implementação
describe("LoginForm", () => {
  it("should show error on invalid credentials", async () => {
    // Arrange
    const { getByRole, getByText } = render(LoginForm);
    server.use(
      http.post("/auth/login", () =>
        HttpResponse.json(
          { message: "Credenciais inválidas" },
          { status: 401 },
        ),
      ),
    );

    // Act
    await userEvent.type(
      getByRole("textbox", { name: /email/i }),
      "test@test.com",
    );
    await userEvent.type(getByRole("textbox", { name: /senha/i }), "wrong");
    await userEvent.click(getByRole("button", { name: /entrar/i }));

    // Assert
    expect(getByText(/credenciais inválidas/i)).toBeInTheDocument();
  });
});

// ERRADO: Testa implementação interna
it("should set isLoading to true", () => {
  const wrapper = mount(LoginForm);
  wrapper.vm.handleSubmit();
  expect(wrapper.vm.isLoading).toBe(true); // implementação interna!
});
```

### Security — Frontend

- SEMPRE sanitize HTML antes de renderizar — `v-html` / `dangerouslySetInnerHTML` são vetores de XSS.
- SEMPRE use **Content Security Policy (CSP)** headers restritivos.
- SEMPRE valide inputs no **client E server** — validação client é UX, server é segurança.
- SEMPRE use **HTTPS** everywhere — nunca HTTP em produção.
- SEMPRE armazene tokens em **httpOnly cookies**, nunca em localStorage.
- NUNCA exponha API keys, secrets ou tokens no bundle frontend.
- NUNCA confie em dados vindos do client — sempre validar server-side.

### Developer Experience (DX)

- SEMPRE configure **ESLint + Prettier** com regras estritas (no-unused-vars, no-explicit-any).
- SEMPRE configure **path aliases** (`@/`, `~/`) no tsconfig e bundler.
- SEMPRE use **husky + lint-staged** para pre-commit hooks.
- SEMPRE documente decisões arquiteturais em `AI.md` ou ADRs.
- SEMPRE mantenha hot reload < 500ms — se mais lento, investigue.
- NUNCA use `alert()`, `confirm()` ou `prompt()` nativos do navegador — use bibliotecas de toast (Sonner, React Toastify, etc.) e modais da UI library.
- NUNCA ignore warnings do linter — são bugs futuros.

## 4. Rendering Patterns — Comparison

| Pattern       | FCP | TTI | SEO | Interatividade    | Quando                    |
| ------------- | --- | --- | --- | ----------------- | ------------------------- |
| **SSG**       | ⚡  | ⚡  | ✅  | ❌ depois hydrate | Blogs, docs, landing      |
| **SSR**       | ⚡  | 🟡  | ✅  | 🟡 depois hydrate | Dashboards, e-commerce    |
| **CSR**       | 🔴  | 🔴  | ❌  | ✅ imediata       | Apps autenticados, SPAs   |
| **Streaming** | ⚡  | ⚡  | ✅  | 🟡 progressiva    | Múltiplos data sources    |
| **Islands**   | ⚡  | ⚡  | ✅  | ✅ parcial        | Content sites + interação |
| **RSC**       | ⚡  | ⚡  | ✅  | ✅ seletiva       | Next.js, modern React     |

## 5. Checklist de Code Review Frontend

- [ ] **Arquitetura** — feature-based, componentes < 150 linhas, barrel exports
- [ ] **TypeScript** — strict: true, zero `any`, discriminated unions
- [ ] **State** — menor escopo possível, computed derivados, immutable
- [ ] **Performance** — lazy loading, code splitting, named imports, budget < 200KB
- [ ] **Rendering** — estratégia correta por página, Server Components quando possível
- [ ] **Acessibilidade** — semântico, :focus-visible, contraste, ARIA mínimo
- [ ] **Testes** — comportamento > implementação, AAA, factories, limites mockados
- [ ] **Segurança** — no XSS, CSP, httpOnly cookies, validação server-side
- [ ] **DX** — linting, formatting, path aliases, CI green
- [ ] **Bundle** — analyzer rodou, chunks definidos, compression habilitada

## 6. Ferramentas Essenciais (2025)

| Categoria         | Ferramenta                  | Alternativa         |
| ----------------- | --------------------------- | ------------------- |
| **Bundler**       | Vite                        | Turbopack, esbuild  |
| **Framework**     | Vue 3 / React 19 / Svelte 5 | Astro, Solid        |
| **State**         | Pinia / Zustand / Jotai     | TanStack Store      |
| **Data Fetching** | TanStack Query              | SWR, Apollo         |
| **Testing**       | Vitest + Testing Library    | Jest                |
| **E2E**           | Playwright                  | Cypress             |
| **Linting**       | ESLint 9 (flat config)      | Biome               |
| **Formatting**    | Prettier                    | Biome               |
| **CSS**           | Tailwind CSS 4              | UnoCSS, vanilla CSS |
| **UI Library**    | PrimeVue / shadcn/ui        | Radix, Headless UI  |
| **Monorepo**      | Turborepo / Nx              | pnpm workspaces     |
| **Analytics**     | Sentry + Web Vitals         | Datadog RUM         |

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

