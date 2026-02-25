---
name: PostgreSQL & SQL
description: Validate, optimize, and generate PostgreSQL queries enforcing indexed access, CTEs, window functions, EXPLAIN ANALYZE, and Row Level Security patterns. Prevents full-table scans and query anti-patterns.
---

# PostgreSQL & SQL — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de criar tabelas**, externalize o schema em um artefato.
- Faça **micro-commits**: uma migration por vez.
- **Nunca confie em inputs** — usar prepared statements ou parameterized queries.
- Sempre rodar `EXPLAIN ANALYZE` em queries críticas antes de deploy.
- **Sempre use UUIDv7 para Primary Keys**: Evita fragmentação severa de B-Tree (comum no UUIDv4) pois são ordenáveis no tempo.

## 2. Índices — Dogmas

```sql
-- ✅ CERTO — índice composto na ordem da query
CREATE INDEX idx_leads_tenant_status
  ON leads (tenant_id, status)
  WHERE deleted_at IS NULL;  -- Partial index (exclui deletados)

-- Query que usa o índice:
SELECT * FROM leads
  WHERE tenant_id = $1 AND status = 'active'
  AND deleted_at IS NULL;

-- ❌ ERRADO — índice em ordem inversa (não usado)
CREATE INDEX idx_leads_status_tenant
  ON leads (status, tenant_id);
-- Query filtra por tenant_id primeiro — índice ignorado!
```

### Regras de índice

- Ordem das colunas = ordem mais seletiva primeiro.
- Partial indexes para soft delete (`WHERE deleted_at IS NULL`).
- `UNIQUE` constraint gera índice automaticamente — não duplicar.
- Máximo ~5 índices por tabela (mais = writes lentos).

## 3. CTEs — Queries Complexas

```sql
-- ✅ CERTO — CTE legível para métricas de pipeline
WITH deal_metrics AS (
  SELECT
    owner_id,
    stage,
    COUNT(*) AS deal_count,
    SUM(value) AS total_value,
    AVG(EXTRACT(EPOCH FROM (now() - stage_entered_at)) / 86400) AS avg_days_in_stage
  FROM deals
  WHERE tenant_id = $1 AND deleted_at IS NULL
  GROUP BY owner_id, stage
)
SELECT
  u.name AS owner_name,
  dm.stage,
  dm.deal_count,
  dm.total_value,
  ROUND(dm.avg_days_in_stage, 1) AS avg_days
FROM deal_metrics dm
JOIN users u ON u.id = dm.owner_id
ORDER BY dm.total_value DESC;

-- ❌ ERRADO — subquery aninhada ilegível
SELECT u.name, (SELECT COUNT(*) FROM deals WHERE deals.owner_id = u.id AND ...) AS count
FROM users u WHERE ...;
```

## 4. Window Functions

```sql
-- ✅ CERTO — ranking de vendedores por mês
SELECT
  owner_id,
  name,
  total_closed,
  RANK() OVER (ORDER BY total_closed DESC) AS rank,
  total_closed::numeric / SUM(total_closed) OVER () * 100 AS pct_of_total
FROM (
  SELECT owner_id, SUM(value) AS total_closed
  FROM deals
  WHERE stage = 'closed_won'
    AND closed_at >= date_trunc('month', CURRENT_DATE)
  GROUP BY owner_id
) sub
JOIN users u ON u.id = sub.owner_id;
```

## 5. EXPLAIN ANALYZE

```sql
-- SEMPRE rodar antes de deploy em queries com WHERE complexo
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM leads
  WHERE tenant_id = 'abc' AND status = 'qualified'
  ORDER BY created_at DESC
  LIMIT 20;
```

| O que procurar           | Bom                         | Ruim                          |
| ------------------------ | --------------------------- | ----------------------------- |
| Scan type                | Index Scan, Index Only Scan | Seq Scan em tabela > 10k rows |
| Rows estimated vs actual | Próximos                    | Diferença > 10x               |
| Buffers                  | shared hit (cache)          | shared read (disco)           |
| Execution time           | < 50ms                      | > 500ms                       |

## 6. Paginação — Cursor vs Offset

```sql
-- ✅ CERTO — cursor pagination (O(1) para qualquer page)
SELECT id, name, created_at FROM leads
  WHERE tenant_id = $1
    AND created_at < $2  -- cursor = created_at do último item
  ORDER BY created_at DESC
  LIMIT 20;

-- ❌ ERRADO — OFFSET em tabelas grandes
SELECT * FROM leads
  ORDER BY created_at DESC
  OFFSET 100000 LIMIT 20;
-- Escaneia 100k rows antes de retornar 20!
```

## 7. Segurança

- **Prepared statements** sempre. Nunca string concatenation.
- `GRANT` mínimo: app user com SELECT/INSERT/UPDATE, nunca SUPERUSER.
- RLS habilitado em tabelas multi-tenant.
- Passwords com `pgcrypto` (`crypt(password, gen_salt('bf'))`).
- Backups automáticos e testados regularmente.

## 8. Anti-Patterns

- ❌ `SELECT *` — listar colunas explicitamente
- ❌ `NOT IN (subquery)` — usar `NOT EXISTS` (performance)
- ❌ Funções em WHERE (`WHERE LOWER(email) = ...`) — criar functional index
- ❌ Transactions longas (> 5s) — dividir em batches
- ❌ `LIKE '%termo%'` — usar `pg_trgm` + GIN index ou full-text search
