---
name: Drizzle ORM
description: Architect, generate, and optimize Drizzle ORM schemas and queries for Edge/Serverless environments. Enforces relational queries (RQB), typed migrations, strict performance boundaries, and zero C++ dependencies.
---

# Drizzle ORM

O Drizzle ORM assumiu a vanguarda do ecossistema TypeScript em 2024 ao abandonar a dependência de Engine em C++ do Prisma, suportando perfeitamente a compilação cruzada para Edge Functions (Vercel, Cloudflare Workers, Supabase Edge) com inicialização na casa dos *Single-Digit Milliseconds*.

## 🏛️ Dogmas de Arquitetura Drizzle ORM

1. **ABOLIR O `drizzle-kit push` EM PRODUÇÃO:** A instrução `push` é para prototipagem. Em sistemas reais, é estritamente obrigatório usar `drizzle-kit generate` criando arquivos `.sql` brutos versionados e aplicando usando fluxos controlados de Deploy CI/CD (`drizzle-kit migrate`).
2. **USE "RQB" (RELATIONAL QUERY BUILDER) PARA LIGAÇÕES:** Em versões mais recentes (v2), NUNCA escreva Joins complexas com `db.select().leftJoin()` se você só quer dados engavetados (Nested Data). Use OBRIGATORIAMENTE o novo motor relacional `db.query.tableName.findMany({ with: { relations: true } })`. O Drizzle converte isso magicamente em *UMA ÚNICA QUERY SQL*, obliterando o N+1 problem internamente sem poluir o código.
3. **MIGRAÇÕES ADITIVAS (BACKWARD COMPATIBLE):** Regra universal para SaaS Serverless: Adicione colunas na Migration 1 e faça deploy no DB. Faça o Deploy do App usando a nova coluna. Somente na Migration 2 você poderá "Dropar" colunas antigas. **Nunca quebre código em execução num edge transiente**. Padrão DML (Dados) isolado do DDL (Estrutura).
4. **PREPARED STATEMENTS (CACHE):** Em tabelas ultra críticas, escape da tradução em tempo de execução através do `.prepare()`. O Drizzle guarda o parser AST e insere apenas os bindings depois.
5. **RAW SQL APENAS QUANDO O TIPO FALHAR:** O Drizzle se orgulha de ser "Se você sabe SQL, você sabe Drizzle". Apenas utilize templates com `sql\` \`` em agregações extremamente complexas (`sql\`SUM(${table.col} * 1.5)\``), caso contrário, mantenha typesafety.

## 🛑 Padrões (Certo vs Errado)

### N+1 Problem em Eager Loading Relacional

**❌ ERRADO** (Fazer loop async buscando subitens no BD, ou fazer JOIN na mão retornando dados espalhados horizontalmente):
```typescript
// N+1 HORRÍVEL - 1 Query pra usuários, +50 queries pra perfis
const users = await db.select().from(schema.users);
for (const user of users) {
  user.profile = await db.select().from(schema.profiles).where(eq(schema.profiles.userId, user.id));
}
```

**✅ CERTO** (Relational Builder resolve em Node e Serverless gerando *Uso Mínimo* de JSON HashMaps DB-side num só hit):
```typescript
const posts = await db.query.users.findMany({
  with: {
    posts: { // <- Puxa todos os posts do usuário em uma query otimizada
      columns: { title: true, created_at: true }, // Buscando só o essencial (Performance)
      orderBy: (posts, { desc }) => [desc(posts.created_at)],
      limit: 5
    }
  }
});
```

### Configuração Edge/Serverless com Pooler HTTP

**❌ ERRADO** (Exibindo drivers obsoletos ou de Node Puro como o "pg" tradicional de client TCP):
```typescript
import { Client } from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
const client = new Client({ connectionString: env.DATABASE_URL });
const db = drizzle(client); // Isso mata a conta Serverless em segundos.
```

**✅ CERTO** (Usando Drivers nativos HTTP/WS compatíveis com Cloudflare/Vercel Edge):
```typescript
import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';

// Via neon-http, 0 Overhead de C++, Sem TCP limit timeout
const sql = neon(process.env.DATABASE_URL!);
export const db = drizzle(sql, { schema });
```

## 🔄 Fluxo de Migração Ideal
Em CI/CD para Next.js App Router (onde deploys e migrações são desacoplados):
1. **Commit:** Desenvolvedor altera o `schema.ts`. Roda `npx drizzle-kit generate`.
2. **Review:** DBAs/Sêniors olham a pasta `drizzle/0001_initial.sql` dentro do PR.
3. **Deploy Migration:** O Action do GitHub roda Script Customizado instanciando o Driver do Cloudflare/Neon e acionando pacote `migrate(db, { migrationsFolder: 'drizzle' })` antes do Next-build.
