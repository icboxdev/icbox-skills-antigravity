---
name: Next.js App Router Deep
description: Architect, validate, and optimize Next.js App Router applications enforcing RSC boundaries, Server Actions, caching strategies, streaming, Partial Prerendering (PPR), data fetching patterns, and route handler best practices.
---

# Next.js App Router Deep — RSC, Caching, Streaming & Server Actions

## 1. Propósito

Dominar os patterns avançados do Next.js App Router para auditar e otimizar aplicações. Cobre RSC boundaries (quando usar `"use client"`), caching, revalidação, streaming, PPR, e Server Actions com validação.

## 2. Dogmas Arquiteturais

### Server-First

**O padrão é Server Component.** Só adicione `"use client"` quando NECESSÁRIO (interatividade, hooks de estado, event handlers, browser APIs).

### A Fronteira é uma Decisão Arquitetural

A diretiva `"use client"` marca uma **fronteira**. Tudo importado por um Client Component se torna client. Empurre a fronteira o mais para baixo possível na árvore.

### Data Fetching no Servidor

**NUNCA** use `useEffect` + `fetch` para dados que podem ser buscados no servidor. Use `async` Server Components ou Server Actions.

### Caching é Opt-In (Next.js 15+)

A partir do Next.js 15, `fetch()` NÃO cacheia por padrão. Use `cache: 'force-cache'` explicitamente ou `unstable_cache` para caching.

## 3. Patterns Essenciais

### 3.1 RSC Boundary — Leaf Client Components

```tsx
// CERTO — Server Component busca dados, Client Component renderiza UI interativa
// app/users/page.tsx (Server Component)
import { UserTable } from "./user-table";

export default async function UsersPage() {
  const users = await db.user.findMany();  // Busca no servidor
  return <UserTable initialData={users} />;
}

// app/users/user-table.tsx (Client Component — leaf)
"use client";
import { useState } from "react";

export function UserTable({ initialData }: { initialData: User[] }) {
  const [search, setSearch] = useState("");
  const filtered = initialData.filter(u => u.name.includes(search));
  return (
    <>
      <input value={search} onChange={e => setSearch(e.target.value)} />
      <table>{filtered.map(u => <tr key={u.id}><td>{u.name}</td></tr>)}</table>
    </>
  );
}
```

```tsx
// ERRADO — Página inteira como Client Component
"use client";  // ← Toda a página é client = sem SSR, sem SEO
import { useEffect, useState } from "react";

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  useEffect(() => {
    fetch("/api/users").then(r => r.json()).then(setUsers);
  }, []);
  // Waterfall: HTML vazio → JS download → fetch → render
}
```

### 3.2 Server Actions com Validação

```tsx
// CERTO — Server Action com Zod validation
"use server";
import { z } from "zod";
import { revalidatePath } from "next/cache";

const createUserSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
});

export async function createUser(formData: FormData) {
  const parsed = createUserSchema.safeParse({
    name: formData.get("name"),
    email: formData.get("email"),
  });

  if (!parsed.success) {
    return { error: parsed.error.flatten().fieldErrors };
  }

  await db.user.create({ data: parsed.data });
  revalidatePath("/users");
  return { success: true };
}
```

```tsx
// ERRADO — Server Action sem validação
"use server";
export async function createUser(formData: FormData) {
  await db.user.create({
    data: {
      name: formData.get("name") as string,   // ← Sem validação, cast perigoso
      email: formData.get("email") as string,
    },
  });
}
```

### 3.3 Caching e Revalidação

```tsx
// CERTO — Cache explícito com revalidação por tempo
// Next.js 15+: fetch não cacheia por padrão
async function getAnalytics() {
  const res = await fetch("https://api.example.com/analytics", {
    next: { revalidate: 300 },  // Revalida a cada 5 minutos
  });
  return res.json();
}

// unstable_cache para queries não-fetch
import { unstable_cache } from "next/cache";

const getCachedUsers = unstable_cache(
  async () => db.user.findMany(),
  ["users-list"],           // Cache key
  { revalidate: 60 }       // 60 segundos
);
```

```tsx
// ERRADO — Assumir que fetch cacheia automaticamente (v15+)
async function getData() {
  const res = await fetch("https://api.example.com/data");
  // Sem next.revalidate ou cache option = no caching em Next 15+
  return res.json();
}
```

### 3.4 Streaming com Suspense

```tsx
// CERTO — Streaming progressivo com Suspense boundaries
import { Suspense } from "react";

export default function DashboardPage() {
  return (
    <div className="grid grid-cols-3 gap-4">
      <Suspense fallback={<StatCardSkeleton />}>
        <RevenueCard />          {/* Streama quando pronto */}
      </Suspense>
      <Suspense fallback={<StatCardSkeleton />}>
        <UsersCard />            {/* Streama independente */}
      </Suspense>
      <Suspense fallback={<ChartSkeleton />}>
        <AnalyticsChart />       {/* Streama independente */}
      </Suspense>
    </div>
  );
}

async function RevenueCard() {
  const revenue = await getRevenue();  // Busca async
  return <StatCard title="Receita" value={revenue} />;
}
```

### 3.5 Route Handlers (API Routes)

```tsx
// CERTO — Route handler tipado com validação
// app/api/users/route.ts
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

const querySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const parsed = querySchema.safeParse(Object.fromEntries(searchParams));

  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.flatten() }, { status: 400 });
  }

  const { page, limit } = parsed.data;
  const users = await db.user.findMany({ skip: (page - 1) * limit, take: limit });
  return NextResponse.json({ data: users, meta: { page, limit } });
}
```

## 4. Layout Patterns

```tsx
// CERTO — Layout com Sidebar + Main Content
// app/(authenticated)/layout.tsx
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar />                              {/* shrink-0 */}
      <main className="flex flex-1 flex-col min-h-0 overflow-auto p-6">
        {children}
      </main>
    </div>
  );
}
```

## 5. Performance Checklist

- [ ] `"use client"` apenas em leaf components interativos
- [ ] Data fetching em Server Components (nunca useEffect para dados iniciais)
- [ ] Suspense boundaries para streaming
- [ ] `loading.tsx` em cada route group
- [ ] `error.tsx` em cada route group
- [ ] Images com `next/image` (lazy loading automático)
- [ ] Dynamic imports para componentes pesados: `dynamic(() => import("..."), { ssr: false })`
- [ ] Metadata API para SEO (`generateMetadata`)

## 6. Zero-Trust

- **NUNCA** colocar `"use client"` no layout root — torna toda a app client.
- **NUNCA** importar componentes de server em client components sem serialização.
- **NUNCA** usar `window`, `document` ou localStorage em Server Components.
- **SEMPRE** validar Server Action inputs com Zod antes de processar.
- **SEMPRE** usar `revalidatePath` ou `revalidateTag` após mutações.
