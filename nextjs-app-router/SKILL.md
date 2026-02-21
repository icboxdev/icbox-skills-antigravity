---
name: Next.js (App Router)
description: Validate, refactor, and generate Next.js code using App Router, React Server Components (RSC), and Server Actions. Imposes strict typing, prohibits client-side fetching where unnecessary, and enforces caching strategies.
---

# Next.js App Router — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de gerar qualquer feature**, externalize a arquitetura proposta em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: edite um componente/route por vez, nunca reescreva layouts inteiros.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- **Server Components são o padrão**. `"use client"` é a exceção, não a regra.

## 2. Estrutura de Projeto

```
app/
├── layout.tsx              # Root layout (fonts, providers)
├── page.tsx                # Home page (Server Component)
├── (auth)/                 # Route Group — não aparece na URL
│   ├── login/page.tsx
│   └── register/page.tsx
├── dashboard/
│   ├── layout.tsx          # Dashboard layout
│   ├── page.tsx
│   └── [id]/page.tsx       # Dynamic route
├── api/                    # Route Handlers (REST endpoints)
│   └── webhooks/route.ts
├── _components/            # Componentes compartilhados
├── _lib/                   # Utils, db, auth
│   ├── actions/            # Server Actions
│   ├── db.ts               # Prisma/Drizzle client
│   └── auth.ts             # NextAuth/Clerk config
└── _types/                 # TypeScript types
```

## 3. Server Components — Padrão

```tsx
// ✅ CERTO — Server Component (padrão, sem "use client")
// Fetch direto no componente, zero JS enviado ao browser
import { db } from "@/_lib/db";

export default async function UsersPage() {
  const users = await db.user.findMany({ take: 20 });

  return (
    <main>
      <h1>Usuários</h1>
      <ul>
        {users.map((u) => (
          <li key={u.id}>{u.name}</li>
        ))}
      </ul>
    </main>
  );
}

// ❌ ERRADO — useEffect + useState para fetch (client-side desnecessário)
("use client");
import { useState, useEffect } from "react";

export default function UsersPage() {
  const [users, setUsers] = useState([]);
  useEffect(() => {
    fetch("/api/users")
      .then((r) => r.json())
      .then(setUsers);
  }, []);
  // Envia React + fetch pro browser SEM necessidade
}
```

## 4. `"use client"` — Apenas Quando Necessário

Use `"use client"` **somente** para:

- `useState`, `useEffect`, `useRef` (hooks de estado/ciclo de vida)
- Event handlers (`onClick`, `onChange`, `onSubmit`)
- Browser APIs (`window`, `localStorage`, `IntersectionObserver`)

```tsx
// ✅ CERTO — isolar interatividade em componente client pequeno
"use client";
export function SearchInput({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState("");
  return (
    <input
      value={query}
      onChange={(e) => setQuery(e.target.value)}
      onKeyDown={(e) => e.key === "Enter" && onSearch(query)}
    />
  );
}

// A page pai permanece Server Component:
export default async function SearchPage() {
  return (
    <main>
      <SearchInput onSearch={/* Server Action */} />
      <ServerResults />
    </main>
  );
}
```

## 5. Server Actions — Zero-Trust

```tsx
// ✅ CERTO — Server Action com Zod validation
"use server";
import { z } from "zod";
import { revalidatePath } from "next/cache";

const CreateUserSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email(),
});

export async function createUser(formData: FormData) {
  const parsed = CreateUserSchema.safeParse({
    name: formData.get("name"),
    email: formData.get("email"),
  });

  if (!parsed.success) {
    return { error: parsed.error.flatten().fieldErrors };
  }

  await db.user.create({ data: parsed.data });
  revalidatePath("/users");
}

// ❌ ERRADO — Server Action sem validação
("use server");
export async function createUser(formData: FormData) {
  await db.user.create({
    data: {
      name: formData.get("name") as string, // Cast cego!
      email: formData.get("email") as string, // Sem validação!
    },
  });
}
```

## 6. Caching & Revalidation

```tsx
// ISR — revalidar a cada 60 segundos
export const revalidate = 60;

// Force dynamic (no cache) — para dados em tempo real
export const dynamic = "force-dynamic";

// On-demand revalidation via Server Action
import { revalidatePath, revalidateTag } from "next/cache";
revalidatePath("/dashboard");
revalidateTag("users");
```

- **Streaming** com `<Suspense>` para UX progressiva.
- **Route Groups** `(group)` para organizar sem afetar URLs.
- **Parallel Routes** `@slot` para layouts complexos.

## 7. Otimizações Obrigatórias

- `next/image` para **todas** as imagens (lazy load, AVIF/WebP, responsive).
- `next/font` para fontes (subconjunto, no layout shift).
- Metadata API para SEO (`generateMetadata`).
- `loading.tsx` e `error.tsx` em cada route segment.
- Dynamic imports com `next/dynamic` para componentes pesados client-side.

## 8. Segurança

- **Zod** em toda Server Action e Route Handler. Nunca confiar em `formData` bruto.
- Secrets via `process.env` (não prefixados com `NEXT_PUBLIC_`).
- Middleware para auth guards (`middleware.ts` na raiz).
- Rate limiting em Route Handlers via headers/IP.
- CSP headers via `next.config.js`.
