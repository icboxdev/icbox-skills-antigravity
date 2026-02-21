---
name: Supabase Backend
description: Validate, architect, and secure Supabase backends enforcing Row Level Security (RLS), cookie-based auth, Storage policies, Edge Functions, and Realtime channels. Covers PKCE flow, service role safety, and migration discipline.
---

# Supabase Backend — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de criar tabelas**, externalize o modelo de dados em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: crie uma tabela + suas policies por vez.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- **RLS é obrigatório** em toda tabela pública. Tabela sem RLS = dados abertos ao mundo.
- **Service Role Key** NUNCA no frontend. Apenas em server-side (Edge Functions, API Routes).

## 2. Auth — Dogmas

### 2.1 PKCE Flow para SSR (NestJS, Next.js)

```typescript
// ✅ CERTO — PKCE flow server-side com cookie
import { createServerClient } from "@supabase/ssr";

export function createSupabaseServer(req: Request, res: Response) {
  return createServerClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => parseCookies(req),
        setAll: (cookies) =>
          cookies.forEach(({ name, value, options }) =>
            res.cookie(name, value, {
              ...options,
              httpOnly: true,
              sameSite: "lax",
            }),
          ),
      },
    },
  );
}

// ❌ ERRADO — token no localStorage (XSS vulnerável)
const { data } = await supabase.auth.signInWithPassword({ email, password });
localStorage.setItem("token", data.session!.access_token);
// Qualquer script injetado rouba o token!
```

### 2.2 Proteção de rotas

```typescript
// ✅ CERTO — verificar session no server antes de servir dados
const supabase = createSupabaseServer(req, res);
const {
  data: { user },
  error,
} = await supabase.auth.getUser();

if (!user) {
  throw new UnauthorizedException("Session inválida");
}

// ❌ ERRADO — confiar no getSession() sem verificar JWT
const {
  data: { session },
} = await supabase.auth.getSession();
// getSession() lê do storage local — pode ser manipulado!
```

## 3. Row Level Security (RLS) — Critério #1

### 3.1 Sempre habilitar RLS

```sql
-- ✅ CERTO — RLS habilitado + policies explícitas
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;

-- Usuários veem apenas seus leads
CREATE POLICY "users_own_leads" ON leads
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Usuários criam leads para si mesmos
CREATE POLICY "users_create_leads" ON leads
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ❌ ERRADO — tabela sem RLS (TODOS veem tudo)
CREATE TABLE leads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id),
  email text
);
-- Esqueceu ALTER TABLE leads ENABLE ROW LEVEL SECURITY!
```

### 3.2 Pattern: Multi-tenant com org_id

```sql
-- ✅ CERTO — RLS por organização
CREATE POLICY "org_members_access" ON deals
  FOR ALL
  TO authenticated
  USING (
    org_id IN (
      SELECT org_id FROM org_members
      WHERE user_id = (SELECT auth.uid())
    )
  );
```

### 3.3 Service Role bypassa RLS — CUIDADO

```typescript
// ✅ CERTO — service role APENAS no server, para operações admin
import { createClient } from "@supabase/supabase-js";

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!, // APENAS server-side!
);

// ❌ ERRADO — service role no frontend
const supabase = createClient(url, "eyJ..."); // Service key no browser!
// BYPASSA TODAS as RLS policies — acesso total ao banco!
```

## 4. Storage — Dogmas

```sql
-- ✅ CERTO — bucket com policies de acesso
INSERT INTO storage.buckets (id, name, public)
  VALUES ('avatars', 'avatars', true);

-- Leitura pública, upload apenas pelo dono
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "avatars_owner_upload" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );
```

- Organizar por `{user_id}/{filename}` para isolar uploads.
- Signed URLs com expiração para arquivos privados.
- Validar MIME type e tamanho no client E no server.

## 5. Edge Functions

```typescript
// ✅ CERTO — Edge Function com JWT verification
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  // Queries respeitam RLS do usuário autenticado
  const { data, error } = await supabase.from("profiles").select("*");

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});

// ❌ ERRADO — Edge Function sem verificar auth
// Deno.serve(async (req) => {
//   const supabase = createClient(url, SERVICE_KEY); // Bypassa RLS!
//   const { data } = await supabase.from('profiles').select('*');
// });
```

## 6. Realtime

```typescript
// ✅ CERTO — channel com topico específico
const channel = supabase
  .channel("room:123")
  .on(
    "postgres_changes",
    {
      event: "INSERT",
      schema: "public",
      table: "messages",
      filter: "room_id=eq.123",
    },
    (payload) => {
      addMessage(payload.new);
    },
  )
  .subscribe();

// Cleanup obrigatório
onUnmounted(() => supabase.removeChannel(channel));
```

- RLS policies em `realtime.messages` para channels privados.
- Sempre fazer `removeChannel()` no unmount (evitar memory leaks).
- Usar `filter` para receber apenas dados relevantes.

## 7. Migrations

- Usar Supabase CLI: `supabase migration new <name>`.
- Nunca editar migrations já aplicadas.
- RLS policies e triggers DENTRO das migrations (versionados).
- Testar em branch antes de aplicar em produção.

## 8. Segurança — Checklist

- [ ] RLS habilitado em TODA tabela pública
- [ ] `auth.uid()` usado em TODA policy (não confiar em frontend)
- [ ] Service Role Key APENAS no server
- [ ] PKCE flow para SSR (não localStorage)
- [ ] Storage policies por bucket + path
- [ ] Edge Functions com JWT verify habilitado
- [ ] Variáveis sensíveis no Vault, não em `.env` commitado
