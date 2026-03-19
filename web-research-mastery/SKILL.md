---
name: Web Research Mastery
description: Execute, optimize, and validate web research workflows for finding documentation, debugging errors, discovering APIs, and solving complex technical problems. Enforces structured query decomposition, advanced search operators, source evaluation, iterative refinement, and Context7/MCP documentation lookup.
---

# Web Research Mastery — Diretrizes Senior+

## 0. Princípio Fundamental: Pesquisar É Engenharia, Não Sorte

Pesquisa web eficaz é **determinística, não aleatória**. O agente que pesquisa bem:
- Decompõe o problema antes de pesquisar.
- Formula queries precisas com operadores avançados.
- Avalia fontes por autoridade antes de confiar.
- Verifica soluções encontradas contra o contexto real.
- Refina iterativamente até encontrar a resposta correta.

> ⚠️ **Crime**: Pesquisar `"como fazer X"` genérico e aceitar o primeiro resultado. Pesquisa é ciência — hipótese, teste, validação.

---

## 1. Workflow Obrigatório: DQEVR (5 Fases)

Toda pesquisa web DEVE seguir este workflow **antes de gerar código ou responder**:

```
┌──────────────────────────────────────────────────────────────────┐
│  D → Decompose: Quebrar problema em sub-questões atômicas       │
│  Q → Query:     Formular queries precisas com operadores        │
│  E → Evaluate:  Avaliar fontes por autoridade e recência        │
│  V → Verify:    Validar solução contra contexto do projeto      │
│  R → Refine:    Se insuficiente, reformular e repetir           │
└──────────────────────────────────────────────────────────────────┘
```

### 1.1 Decompose — Quebrar o Problema

ANTES de pesquisar, decompor o problema em sub-questões independentes:

```
# ERRADO: pesquisar direto
"como integrar pagamento PIX com Rust e Axum"

# CERTO: decompor primeiro
1. Qual a API do provedor PIX que vou usar? (Asaas, Mercado Pago, etc.)
2. Qual o endpoint específico para gerar QR Code PIX?
3. Qual o formato do payload esperado?
4. Como verificar webhook de confirmação de pagamento?
5. Qual a lib HTTP recomendada em Rust? (reqwest)
→ Pesquisar CADA sub-questão separadamente
```

### 1.2 Query — Formular Queries Precisas

#### Operadores Avançados Obrigatórios

| Operador | Uso | Exemplo |
|---|---|---|
| `"frase exata"` | Error messages, nomes de função | `"cannot borrow as mutable"` |
| `site:` | Limitar a domínio confiável | `site:docs.rs tokio spawn` |
| `-excluir` | Remover ruído | `rust web framework -rocket -actix` |
| `intitle:` | Buscar em títulos de página | `intitle:"API reference" stripe` |
| `filetype:` | Buscar por tipo de arquivo | `axum middleware filetype:rs` |
| `after:YYYY` | Filtrar por data | `next.js app router after:2024` |
| `OR` | Alternativas | `"connection pool" (sqlx OR diesel)` |
| `*` (wildcard) | Preencher lacunas | `rust "how to * async"` |

#### Regras de Formulação

```
# ERRADO: query genérica
"como fazer autenticação no rust"

# CERTO: query precisa com contexto
"axum middleware auth JWT tower-http extract State 2024"

# ERRADO: colar error inteiro com paths locais
"error[E0382]: borrow of moved value: `connection` at /home/user/project/src/main.rs:42"

# CERTO: error genérico + contexto mínimo
"rust E0382 borrow of moved value connection sqlx pool"

# ERRADO: buscar sem especificar linguagem/framework
"how to parse JSON"

# CERTO: linguagem + framework + contexto
"serde deserialize nested JSON optional fields rust"
```

### 1.3 Evaluate — Avaliar Fontes

#### Hierarquia de Confiabilidade (TOP → BOTTOM)

```
Tier 1 — Fonte Canônica (SEMPRE preferir)
├── Documentação oficial (docs.rs, react.dev, nextjs.org)
├── Repositório oficial no GitHub (README, examples/, tests/)
├── RFC / Specification (IETF RFCs, OpenAPI specs)
└── Blog oficial do projeto (blog.rust-lang.org, vercel.com/blog)

Tier 2 — Fonte Confiável (usar com validação)
├── Stack Overflow (respostas com > 10 upvotes, aceitas)
├── GitHub Issues/Discussions (com respostas de maintainers)
├── Blogs técnicos reconhecidos (tokio.rs/blog, lpalmieri.com)
└── Context7 / MCP docs (documentação indexada e versionada)

Tier 3 — Fonte Útil (usar com cautela)
├── Dev.to, Medium (verificar data e autor)
├── Reddit (r/rust, r/reactjs — verificar consenso)
└── Tutoriais genéricos (cruzar com Tier 1)

Tier 4 — Fonte Suspeita (NUNCA confiar cegamente)
├── Respostas de AI sem citação
├── Blogs desatualizados (> 2 anos em tech que evolui rápido)
├── Fóruns sem moderação técnica
└── Conteúdo gerado automaticamente (fazendas de SEO)
```

#### Sinais de Alerta (Red Flags)

- ⛔ Artigo sem data de publicação
- ⛔ Código sem imports/context (snippet incompleto)
- ⛔ Versão da lib diferente da que o projeto usa
- ⛔ Solução que ignora error handling ("just unwrap")
- ⛔ Resposta que contradiz a documentação oficial

### 1.4 Verify — Validar Contra Contexto

Toda solução encontrada DEVE ser validada:

1. **Versão compatível?** — A solução é para a versão da lib/framework do projeto?
2. **Compila/funciona?** — Testar mentalmente ou executar antes de aplicar.
3. **Seguro?** — Não introduz vulnerability? Respeita padrões do projeto?
4. **Idiomático?** — Segue os padrões/skills do projeto, não é "gambiarra"?
5. **Completo?** — Cobre edge cases, error handling, tipos corretos?

### 1.5 Refine — Reformular Se Insuficiente

Se a pesquisa não retornou resultado satisfatório:

```
Tentativa 1: Query específica → sem resultado
    ↓
Tentativa 2: Reformular com sinônimos/termos alternativos
    ↓
Tentativa 3: Buscar no GitHub Issues/Discussions do projeto
    ↓
Tentativa 4: Buscar no código-fonte do projeto (tests/, examples/)
    ↓
Tentativa 5: Context7 ou MCP docs para versão específica
    ↓
Tentativa 6: Generalizar o problema e buscar o padrão subjacente
    ↓
Tentativa 7: Perguntar ao usuário por contexto adicional
```

---

## 2. Estratégias por Cenário

### 2.1 Debugging — Resolver Erro

```
Workflow:
1. Copiar error message EXATO (sem paths locais, sem line numbers)
2. Pesquisar: "error_code" + contexto mínimo
3. Se sem resultado: generalizar removendo detalhes projeto-específicos
4. Verificar GitHub Issues do projeto com: site:github.com/<org>/<repo> "error message"
5. Stack Overflow: site:stackoverflow.com [tag] "error message"
```

```
# Exemplo: erro de compilação Rust
Error: "the trait `FromRequest` is not implemented for `Json<MyStruct>`"

# Query 1 (específica):
"axum FromRequest not implemented for Json" site:github.com/tokio-rs/axum

# Query 2 (Stack Overflow):
site:stackoverflow.com [rust] [axum] "FromRequest not implemented" Json

# Query 3 (docs):
site:docs.rs axum Json FromRequest extractor

# Query 4 (generalizar):
axum "Json extractor" custom struct derive Deserialize
```

### 2.2 Documentação — Encontrar API/Lib

```
Workflow:
1. Context7 primeiro: resolve-library-id → query-docs
2. Se insuficiente: docs oficiais (site:docs.rs, site:react.dev)
3. Se insuficiente: GitHub README + examples/
4. Se insuficiente: pesquisa web com operadores
```

```
# Buscar API de uma lib Rust:
site:docs.rs sqlx query_as macro usage

# Buscar componente React:
site:ui.shadcn.com dialog controlled form

# Buscar API externa (brasileiro):
site:docs.asaas.com.br pix qr-code api

# Buscar padrão arquitetural:
"adapter pattern" rust async trait example 2024
```

### 2.3 Integração — Conectar com API Externa

```
Workflow:
1. Documentação oficial da API (Swagger/OpenAPI spec se disponível)
2. SDK/client library oficial (crates.io, npm)
3. Exemplos de integração no GitHub
4. Verificar rate limits, autenticação, e formatos de resposta
5. Webhooks: verificar formato de assinatura e eventos disponíveis
```

```
# Encontrar docs de API:
"<nome-api>" API reference REST documentation

# Encontrar OpenAPI spec:
"<nome-api>" openapi swagger specification filetype:yaml OR filetype:json

# Encontrar SDK:
"<nome-api>" SDK (rust OR typescript OR node) crate npm official

# Encontrar exemplos:
site:github.com "<nome-api>" example integration (rust OR typescript)
```

### 2.4 Padrão Arquitetural — Encontrar Best Practice

```
Workflow:
1. Verificar skills existentes primeiro (OBRIGATÓRIO)
2. Context7 para padrões da stack específica
3. Pesquisar padrão + stack + "best practices" + ano recente
4. Verificar blogs de autoridade (tokio.rs, vercel.com/blog)
5. Cruzar com documentação oficial
```

```
# Exemplo: multi-tenancy patterns
"multi-tenant" "row level security" postgresql rust axum after:2023

# Exemplo: state management
"zustand vs jotai vs recoil" react 2024 comparison benchmark

# Exemplo: caching strategy
"cache invalidation" "stale-while-revalidate" tanstack query react
```

---

## 3. Ferramentas de Pesquisa — Ordem de Prioridade

### 3.1 Antes de Pesquisar na Web

```
CHECKLIST — executar NESTA ordem antes de ir para web:

1. ✅ Consultar Skills existentes (view_file SKILL.md)
2. ✅ Consultar Knowledge Items (KIs) relevantes
3. ✅ Consultar logs de conversas anteriores (se aplicável)
4. ✅ Context7: resolve-library-id → query-docs
5. ✅ MCP servers especializados (primevue, shadcn, supabase, adonisjs)
6. ✅ Codebase local: grep_search, find_by_name no projeto
7. ── Só então → search_web
8. ── Se necessário → read_url_content para docs específicos
```

### 3.2 search_web — Quando e Como

```
QUANDO usar search_web:
- Quando Context7 e MCP servers não têm a informação
- Quando precisa de informação atualizada (breaking changes, releases)
- Quando debugando erro específico não documentado
- Quando pesquisando API externa sem MCP server

COMO formular a query:
- SEMPRE incluir: tecnologia + contexto específico + ano (se relevante)
- NUNCA queries genéricas de 2-3 palavras
- Mínimo 5 keywords relevantes por query
- Usar operadores avançados (site:, "frase", -, OR)
```

### 3.3 read_url_content — Quando e Como

```
QUANDO usar read_url_content:
- Ler documentação oficial completa de um endpoint/feature
- Ler README de repositório GitHub
- Ler API reference de provedor externo
- Ler post técnico de blog confiável (Tier 1-2)

QUANDO NÃO usar:
- Páginas que requerem JavaScript (SPAs) — não funciona
- Páginas que requerem login — usar browser tool
- Várias páginas sem objetivo claro — foco primeiro
```

---

## 4. Anti-Patterns — O Que NUNCA Fazer

```
❌ NUNCA pesquisar "como fazer X" sem decompor o problema antes
❌ NUNCA aceitar primeira resposta sem verificar fonte e versão
❌ NUNCA copiar código sem entender imports, tipos, e error handling
❌ NUNCA ignorar a data do artigo/resposta (tech evolui rápido)
❌ NUNCA pesquisar com error message contendo paths locais do projeto
❌ NUNCA confiar em snippet que não compila ou que usa `any`/`unwrap` sem justificativa
❌ NUNCA fazer mais de 5 pesquisas web para o mesmo sub-problema sem reformular a abordagem
❌ NUNCA pesquisar na web sem antes consultar skills, KIs, e Context7
❌ NUNCA inventar APIs, endpoints, ou funções que não foram verificados em docs oficiais
❌ NUNCA assumir que a versão da lib no resultado é a mesma do projeto
```

---

## 5. Templates de Pesquisa — Copiar e Usar

### 5.1 Debug Error

```
Template: "<error_code>" "<key_message>" <framework> <language> site:stackoverflow.com OR site:github.com
Exemplo:  "E0277" "the trait bound" axum rust site:stackoverflow.com OR site:github.com/tokio-rs
```

### 5.2 Encontrar Documentação

```
Template: site:<official_docs_domain> <feature> <keyword> <keyword>
Exemplo:  site:docs.rs sqlx::query_as macro derive FromRow
```

### 5.3 Encontrar Exemplos

```
Template: site:github.com "<library>" example <feature> <language> extension:<ext>
Exemplo:  site:github.com "axum" example websocket rust extension:rs
```

### 5.4 Comparar Alternativas

```
Template: "<tech_a>" vs "<tech_b>" <context> comparison benchmark after:<year>
Exemplo:  "diesel" vs "sqlx" async postgres rust comparison after:2024
```

### 5.5 API Externa Brasileira

```
Template: "<api_name>" API REST documentação integração <feature>
Exemplo:  "Asaas" API REST documentação integração PIX QR Code
```

### 5.6 Padrão Arquitetural

```
Template: "<pattern>" <framework> <language> best practices implementation after:<year>
Exemplo:  "circuit breaker" reqwest rust async implementation after:2024
```

---

## 6. Domínios Confiáveis — Quick Reference

### Rust
- `docs.rs` — documentação de crates
- `doc.rust-lang.org` — docs oficiais da linguagem
- `github.com/tokio-rs` — Tokio, Axum, Hyper, Tower
- `blog.rust-lang.org` — blog oficial
- `users.rust-lang.org` — fórum oficial

### React / Next.js / Frontend
- `react.dev` — docs oficiais React
- `nextjs.org/docs` — docs Next.js
- `ui.shadcn.com` — shadcn/ui docs
- `tanstack.com` — TanStack Query, Router, Table
- `tailwindcss.com` — Tailwind docs

### APIs Brasileiras
- `docs.asaas.com.br` — Asaas (pagamentos)
- `viacep.com.br` — ViaCEP (CEP)
- `brasilapi.com.br` — BrasilAPI (CNPJ, CEP, bancos)
- `servicodados.ibge.gov.br` — IBGE API
- `focusnfe.com.br` — Focus NFe (notas fiscais)

### Infra / DevOps
- `docs.docker.com` — Docker
- `docs.github.com` — GitHub Actions, APIs
- `hub.docker.com` — Docker Hub
- `redis.io` — Redis docs

---

## 7. Checklist — Pesquisa de Qualidade

Antes de considerar a pesquisa concluída, validar:

- [ ] Problema foi decomposto em sub-questões antes de pesquisar?
- [ ] Queries usaram operadores avançados (`site:`, `"exata"`, `-exclude`)?
- [ ] Fontes avaliadas por tier de confiabilidade (Tier 1 > Tier 4)?
- [ ] Data de publicação verificada (não está desatualizado)?
- [ ] Versão da lib/framework verificada contra o projeto?
- [ ] Solução valida contra padrões do projeto (skills, AI.md)?
- [ ] Error handling incluído (não é snippet "happy path only")?
- [ ] Skills e KIs consultados ANTES da pesquisa web?
- [ ] Context7/MCP consultados ANTES de search_web?
- [ ] Se não encontrou em 5 tentativas, reformulou abordagem?
