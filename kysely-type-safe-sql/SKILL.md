---
name: Kysely Type-Safe SQL Builder
description: Architect, establish, and optimize database querying using Kysely. Enforces end-to-end type safety, code generation from schema, edge environments compatibility, and query composition best practices.
---

# Kysely Type-Safe SQL Builder

Kysely não é um ORM clássico cheio de mágica. É o builder SQL para TypeScript mais poderoso do mercado focado em garantir *Type-Safety ABSOLUTA* e autocompletamento em nível de compilação sem abstrair os conceitos que fazem do SQL uma linguagem excelente.

## 🏛️ Dogmas de Arquitetura Kysely

1. **O BANCO É A FONTE DA VERDADE (Codegen):** NUNCA defina interfaces de banco de dados manualmente no TypeScript em produção ("Schema Drift" destrói arquiteturas quando Tabela e TS dessincronizam). OBRIGATÓRIO utilizar `kysely-codegen` acoplado na rotina de build (ou pré-commit) para introspectar o BD e gerar automaticamente o arquivo `DB` types.
2. **A FORÇA ESTÁ NO COMPOSABILITY:** O Kysely brilha ao separar componentes de queries complexas. NUNCA escreva queries monolíticas amarradas num arquivo grande. Quebre partes lógicas da query usando variáveis construtivas que injetem `ExpressionBuilder`, promovendo reuso.
3. **USE O "REPOSITORY PATTERN":** Como o Kysely é uma fina camada sobre SQL, injetá-lo diretamente no Controlador vai tornar a API suja com lógica de Join de BD. OBRIGATÓRIO isolar todas as interações com o DB (e instâncias do `db` do Kysely) em classes ou funções de Repositórios/Facedes (Ex: `UserRepository.findByEmail`).
4. **COMPATIBILIDADE EDGE POR DIALECT:** Kysely usa 0 (zero) dependências nativas, sendo o builder ouro para Edge. Para ambientes edge (Vercel, Cloudflare D1, Turso libSQL), OBRIGATÓRIO plugar Dialects oficiais ou de comunidade mantendo o type-checking global inalterado, e alterando apenas o instanciador do Driver (Ex: `PlanetScaleDialect`, `BunSqliteDialect`).
5. **CRIE ESCAPE HATCHES COM SEGURANÇA (RAW SQL):** Não use Kysely para esconder o SQL. Se uma Dialect específica de banco (ex: Triggers avançados de PostgreSQL, extensões geofaciais GIS) exceder a interface, utilize `sql\` \`` com placeholders para injeção segura de parâmetros. NUNCA concatene strings cruas fora do utilitário `sql\``.

## 🛑 Padrões (Certo vs Errado)

### Tipagem Base

**❌ ERRADO** (Escrever os tipos na mão / risco de desatualização se a Coluna for alterada no devDB):
```typescript
// Anti-pattern de dessincronização
interface Person { id: number; nome_antigo_dropado: string; }
interface Database { person: Person }
const db = new Kysely<Database>({ ... })
```

**✅ CERTO** (Usar introspecção com Codegen e importar Tipos nativos):
```typescript
// Comando de CLI rodado previamente: npx kysely-codegen --out-file src/db/types.ts
import { DB } from './db/types' // O Arquivo é ignorado pelo Git se rodado via CI, ou commitado como source of truth.
import { Kysely, PostgresDialect } from 'kysely'
import { Pool } from 'pg'

export const db = new Kysely<DB>({
  dialect: new PostgresDialect({
    pool: new Pool({ connectionString: env.DATABASE_URL })
  })
})
// Digitando "db.selectFrom('..." o VScode preenche 100% da query
```

### Prevenção de Injeção SQL em Mutações Dinâmicas

**❌ ERRADO** (Injeção via literais sem escape seguro mesmo dentro da classe):
```typescript
// VULNERABILIDADE SQL INJECTION - Kysely falhará na tipagem mas se forçado rodará lixo inseguro.
const tableName = req.body.table; // "users; DROP DB;"
const query = sql`SELECT * FROM ${tableName}`
```

**✅ CERTO** (Forçar Invocação Segura via Referência Kysely Type-Safe):
```typescript
// Utilizando referências de identicadores puros controlados
const { e } = db.dynamic
import { sql } from 'kysely'

const dynamicFilter = userInput;
// Query Builder seguro: Parâmetros vão pro prepareStatement automático ($1)
const users = await db.selectFrom('person')
  .selectAll()
  .where(sql`first_name || ' ' || last_name`, 'ilike', `%${dynamicFilter}%`) // Seguro.
  .execute()
```

### Kysely vs Drizzle (Regra de Escolha)
- **Use DRIZZLE** se a sua infra quer o schema guiado pelo Código (Typescript DDL Migration first) e você quer Query Relacional Mágica baseada em objeto v2.
- **Use KYSELY** se o Banco for Guiado por Migrações SQL ou de DBA, e você quiser a interface SQL absoluta de alto escalão com o Typescript inferindo os tipos direto do DB.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

