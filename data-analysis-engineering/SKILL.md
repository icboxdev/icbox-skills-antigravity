---
name: Data Analysis Software Engineering
description: Architect, generate, validate, and optimize data analysis platforms. Covers dimensional modeling (Star/Snowflake, OLAP), data warehouse and lakehouse design, ETL/ELT pipelines (Airflow, dbt, Spark), real-time streaming (Kafka, Flink), Medallion Architecture (Bronze/Silver/Gold), data observability (lineage, quality, OpenTelemetry), visualization dashboards (React, D3, ECharts), multi-tenant RBAC with Row Level Security, and GDPR-compliant data governance.
---

# Data Analysis Engineering — Diretrizes Senior+

## 0. Princípio Fundamental: Dados Como Produto

Toda plataforma de análise de dados deve tratar dados como produto de primeira classe:
- Dados têm **donos** (Data Owners) com SLAs e contratos explícitos.
- Dados têm **qualidade mensurável** (freshness, completeness, accuracy, uniqueness).
- Dados têm **linhagem rastreável** — todo dado sabe de onde veio.
- Dados têm **controle de acesso granular** — tenant, role e row level.

> ⚠️ **Crime Arquitetural**: Construir pipelines sem testes de qualidade é ato de negligência. Nunca faça um pipeline sem checar completeness, freshness e constraint violations.

---

## 1. Arquiteturas de Dados — Escolha Consciente

### 1.1 Hierarquia de Complexidade

| Arquitetura | Quando Usar | Trade-off |
|---|---|---|
| **Data Warehouse** | BI/reporting, dados estruturados, schemas estáveis | Rígido, mas rápido para queries analíticas |
| **Data Lake** | ML, dados brutos, heterogêneos, volume massivo | Flexível, mas sem governance nativo |
| **Data Lakehouse** (Delta Lake, Iceberg) | Unified analytics + ML + streaming | Melhor dos dois mundos — padrão 2024 |
| **Data Mesh** | Domínios autônomos, múltiplos times | Alta escalabilidade organizacional, overhead de governança |
| **Data Fabric** | Integração cross-cloud, metadata-driven | Complexidade operacional elevada |

**Dogma**: Novos projetos greenfield devem usar **Data Lakehouse** com **Medallion Architecture** por padrão. Data Mesh apenas quando há múltiplos domínios de negócio com times independentes.

### 1.2 Medallion Architecture — Lei Obrigatória

```
[Fontes] → [Bronze] → [Silver] → [Gold] → [BI / ML]
              ↑            ↑          ↑
           Raw data    Cleaned    Aggregated
           (imutável)  Validated  Business-ready
```

**Bronze** (Landing Zone):
- Dados brutos, exatamente como chegam da fonte.
- Imutável — nunca modifique dados Bronze.
- Schema: `raw_<source>_<entity>` (ex: `raw_stripe_payments`).
- Adicione `_ingested_at TIMESTAMPTZ`, `_source STRING`, `_batch_id UUID`.

**Silver** (Conformed):
- Limpeza, validação, deduplicação, tipagem correta.
- Schema: `<entity>` normalizado (ex: `payments`).
- Aqui vivem as entidades de negócio canônicas.
- Aplique `NOT NULL`, `CHECK constraints`, `UNIQUE` constraints.

**Gold** (Business-Ready):
- Agregações, métricas, KPIs, modelos dimensionais.
- Schema: `fact_<metric>`, `dim_<entity>`, `agg_<level>_<metric>`.
- Otimizada para query performance — materialized views, partições.
- Nunca exponha Bronze ou Silver diretamente a BI tools.

```sql
-- CERTO: Gold layer com partição e índice para BI
CREATE TABLE gold.fact_revenue (
  tenant_id UUID NOT NULL,
  date_id INT NOT NULL,           -- FK para dim_date
  product_id INT NOT NULL,        -- FK para dim_product
  revenue_cents BIGINT NOT NULL,
  transaction_count INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
)
PARTITION BY RANGE (date_id);     -- partição por data obrigatória

CREATE INDEX ON gold.fact_revenue (tenant_id, date_id);  -- index composto sempre

-- ERRADO: Expor tabela bruta para BI sem transformação
SELECT * FROM bronze.raw_stripe_payments WHERE tenant_id = $1;  -- NUNCA faça isso
```

---

## 2. Modelagem Dimensional — Dogmas de Ralph Kimball

### 2.1 Star Schema vs Snowflake Schema

**Regra**: Use **Star Schema** para BI reporting (menos joins = faster queries). Use **Snowflake Schema** apenas quando integridade de dados ou complexidade dimensional justificam.

```sql
-- CERTO: Star Schema — Fact Table + Dimensões desnormalizadas
-- Fact Table (métricas brutas, FKs para dimensões)
CREATE TABLE gold.fact_sales (
  sale_id BIGSERIAL PRIMARY KEY,
  date_id INT NOT NULL REFERENCES gold.dim_date(date_id),
  customer_id INT NOT NULL REFERENCES gold.dim_customer(customer_id),
  product_id INT NOT NULL REFERENCES gold.dim_product(product_id),
  amount_cents BIGINT NOT NULL,
  quantity INT NOT NULL,
  tenant_id UUID NOT NULL
);

-- Dimension Table desnormalizada (todos os atributos em uma tabela)
CREATE TABLE gold.dim_customer (
  customer_id SERIAL PRIMARY KEY,         -- Surrogate key (não usar ID da fonte!)
  customer_nk VARCHAR(50) NOT NULL,       -- Natural key (ID da fonte original)
  full_name VARCHAR(255),
  email VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(50),
  country_code CHAR(2),
  customer_segment VARCHAR(50),           -- Enterprise, SMB, Consumer
  valid_from DATE NOT NULL,               -- SCD Type 2
  valid_to DATE,                          -- NULL = registro atual
  is_current BOOLEAN DEFAULT TRUE,
  tenant_id UUID NOT NULL
);

-- ERRADO: usar PKs da fonte operacional como FK no data warehouse
-- fact_sales.customer_id INT REFERENCES operational.customers(id)  ← NUNCA
```

### 2.2 Slowly Changing Dimensions (SCD)

**SCD Type 1** — Sobrescreve (sem histórico): para dados não-históricos (URLs, telefones).
**SCD Type 2** — Nova linha com `valid_from/valid_to`: para dados históricos (endereço, segmento).
**SCD Type 3** — Coluna adicional (histório limitado): raramente usado.

```sql
-- SCD Type 2: sempre use esse padrão para dimensões que mudam ao longo do tempo
UPDATE gold.dim_customer
SET valid_to = NOW()::DATE, is_current = FALSE
WHERE customer_nk = $1 AND is_current = TRUE AND tenant_id = $2;

INSERT INTO gold.dim_customer (customer_nk, full_name, email, customer_segment, valid_from, is_current, tenant_id)
VALUES ($1, $2, $3, $4, NOW()::DATE, TRUE, $5);
```

### 2.3 Fact Table Design Rules

- **Grain** = o que representa UMA linha? Defina antes de criar a tabela.
- Sempre use **surrogate keys** (SERIAL/BIGSERIAL) como PK — nunca UUIDs randômicos em fact tables (degradam b-tree).
- **Additive facts**: podem ser somados em qualquer dimensão (revenue, quantity).
- **Semi-additive facts**: somados em algumas dimensões (account balance — não some across time).
- **Non-additive facts**: nunca some (ratios, percentages — guarde numerador e denominador separadamente).

```sql
-- CERTO: guardar numerador e denominador, não o ratio!
-- fact_metrics: NUNCA guarde conversion_rate FLOAT
-- SEMPRE guarde sessions_count e conversions_count separadamente
conversion_rate = SUM(conversions_count) / NULLIF(SUM(sessions_count), 0)  -- calcule na query

-- ERRADO: guardar ratio pré-calculado
conversion_rate FLOAT  -- não pode ser somado corretamente entre segmentos!
```

---

## 3. Pipelines ETL/ELT — Arquitetura de Produção

### 3.1 Princípios de Pipeline

1. **Idempotência obrigatória** — reexecutar o mesmo pipeline com o mesmo input DEVE produzir o mesmo resultado. Use `INSERT ... ON CONFLICT DO NOTHING` ou `MERGE`.
2. **Backfill-safe** — toda task deve aceitar `execution_date` como parâmetro.
3. **Atomicidade** — ou tudo commit, ou tudo rollback. Nunca estado parcial.
4. **Checkpointing** — salve progresso para retomar em caso de falha.
5. **Dead Letter Queue** — mensagens/registros que falharam vão para DLQ, nunca silenciosamente descartados.

### 3.2 Apache Airflow — Padrões Obrigatórios

```python
# CERTO: DAG idempotente, modular, com retry e alertas
from airflow.decorators import dag, task
from airflow.utils.dates import days_ago
from pendulum import datetime

@dag(
    schedule_interval="@daily",
    start_date=datetime(2024, 1, 1),
    catchup=False,                           # NUNCA True em produção sem análise cuidadosa
    max_active_runs=1,                       # evita runs paralelos no mesmo dataset
    default_args={
        "retries": 3,
        "retry_delay": timedelta(minutes=5),
        "retry_exponential_backoff": True,
        "on_failure_callback": alert_on_failure,  # SEMPRE configurar alertas
    },
    tags=["bronze", "stripe"],
)
def ingest_stripe_payments():
    @task()
    def extract(execution_date=None):
        # Usar execution_date para backfill-safety
        return fetch_stripe_data(date=execution_date)
    
    @task()
    def load_to_bronze(records: list):
        # Idempotente: ON CONFLICT DO NOTHING
        upsert_bronze(records)
    
    data = extract()
    load_to_bronze(data)

# ERRADO: DAG monolítica sem retry, catchup=True sem análise
@dag(catchup=True, default_args={"retries": 0})  # ← receita para desastre
def bad_dag():
    PythonOperator(task_id="do_everything", python_callable=do_everything_at_once)
```

**Airflow: Regras de Ouro**:
- DAGs são **code** — versione no Git, teste unitariamente.
- Nunca use `PythonOperator` para lógica de negócio pesada — delegue a workers externos.
- Pools obrigatórios para controlar concorrência em banco de dados.
- Variáveis sensíveis **sempre** em Airflow Connections ou Vault — jamais em variáveis de ambiente do DAG.
- Monitorar sempre: `dag_duration_seconds`, `task_failure_count`, `data_freshness`.

### 3.3 dbt — Padrões de Transformação

```
project/
├── models/
│   ├── staging/          # Bronze → Normalizado (1:1 com fontes)
│   │   └── stg_stripe__payments.sql
│   ├── intermediate/     # Lógica de negócio, joins, enrichment
│   │   └── int_payments_enriched.sql
│   └── marts/            # Gold layer — pronto para BI
│       ├── finance/
│       │   └── fact_revenue.sql
│       └── core/
│           └── dim_customer.sql
├── tests/
│   ├── assert_revenue_positive.sql
│   └── assert_no_orphan_facts.sql
└── dbt_project.yml
```

```sql
-- CERTO: modelo Staging — 1:1 com fonte, sem lógica de negócio
-- models/staging/stg_stripe__payments.sql
{{ config(materialized='view') }}  -- staging sempre como view (sem custo de storage)

SELECT
  id AS payment_nk,
  customer_id AS customer_nk,
  amount / 100.0 AS amount_dollars,  -- centavos → dólares aqui, não no mart
  currency,
  status,
  created AS created_at,
  {{ current_timestamp() }} AS _dbt_loaded_at
FROM {{ source('stripe', 'payments') }}
WHERE status != 'requires_payment_method'  -- filtros básicos de qualidade aqui

-- CERTO: modelo Mart — lógica de negócio, joins com dimensões
-- models/marts/finance/fact_revenue.sql
{{ config(
  materialized='incremental',
  unique_key='payment_nk',
  partition_by={'field': 'payment_date', 'data_type': 'date'},   -- partição obrigatória
  cluster_by=['tenant_id', 'status'],
) }}

SELECT
  p.payment_nk,
  d.date_id,
  c.customer_id,
  p.amount_dollars,
  p.currency
FROM {{ ref('stg_stripe__payments') }} p
LEFT JOIN {{ ref('dim_date') }} d ON DATE(p.created_at) = d.full_date
LEFT JOIN {{ ref('dim_customer') }} c ON p.customer_nk = c.customer_nk AND c.is_current = TRUE
{% if is_incremental() %}
WHERE p._dbt_loaded_at > (SELECT MAX(_dbt_loaded_at) FROM {{ this }})
{% endif %}
```

**dbt: Testes Obrigatórios**:
```yaml
# schema.yml
models:
  - name: fact_revenue
    columns:
      - name: payment_nk
        tests:
          - unique
          - not_null
      - name: amount_dollars
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              inclusive: false     # valor zero é suspeito
      - name: customer_id
        tests:
          - relationships:
              to: ref('dim_customer')
              field: customer_id
```

---

## 4. Streaming Real-Time — Kafka + Flink

### 4.1 Quando usar Streaming vs Batch

| Caso | Abordagem | Latência |
|---|---|---|
| Fraud detection | Streaming (Flink) | < 100ms |
| Dashboards operacionais | Micro-batch (5-60s) | 5-60s |
| Relatórios financeiros | Batch (dbt diário) | T+1 dia |
| IoT monitoring | Streaming (Kafka) | < 1s |
| ETL de DW | Batch (Airflow + dbt) | horas |

**Dogma**: Não use streaming onde batch resolve. Streaming tem overhead operacional significativo — use apenas quando latência < 60 segundos é requisito real de negócio.

### 4.2 Kafka — Padrões de Tópicos

```
Nomenclatura: <domínio>.<entidade>.<tipo>
Exemplos:
  payments.transactions.events      ← eventos de negócio
  payments.transactions.dlq          ← dead letter queue (OBRIGATÓRIO)
  analytics.page-views.raw           ← dados brutos de analytics
  
Configurações mínimas de produção:
  retention.ms: 604800000    # 7 dias
  replication.factor: 3
  min.insync.replicas: 2     # quorum de escrita
  acks: all                  # garantia de durabilidade
```

### 4.3 Flink — Patterns de Processamento

```java
// CERTO: windowed aggregation com event-time (não processing-time!)
DataStream<PaymentEvent> payments = env
  .fromSource(kafkaSource, WatermarkStrategy
    .<PaymentEvent>forBoundedOutOfOrderness(Duration.ofSeconds(30))  // tolera 30s de atraso
    .withTimestampAssigner((event, ts) -> event.getCreatedAt().toEpochMilli()),
    "Kafka Payments")
  .assignTimestampsAndWatermarks(watermarkStrategy);

DataStream<RevenueAggregate> revenue = payments
  .keyBy(PaymentEvent::getTenantId)
  .window(TumblingEventTimeWindows.of(Time.hours(1)))
  .aggregate(new RevenueAggregateFunction());

// ERRADO: usar processing-time — resultados inconsistentes com dados atrasados
.window(TumblingProcessingTimeWindows.of(Time.hours(1)))  // ← NÃO USE para analytics
```

**Flink: Regras Críticas**:
- Sempre use **event-time**, nunca processing-time para analytics.
- Configure **checkpointing** a cada 30-60s para tolerância a falhas.
- Use **exactly-once** semantics para dados financeiros/críticos.
- Implemente **backpressure monitoring** — sinal de gargalo no pipeline.

---

## 5. Query Optimization — PostgreSQL/OLAP

### 5.1 Regras de Performance

```sql
-- CERTO: query OLAP com partição, índice composto e CTE para legibilidade
WITH monthly_revenue AS (
  SELECT
    d.year,
    d.month,
    p.product_category,
    SUM(f.revenue_cents) AS total_revenue_cents,
    COUNT(DISTINCT f.customer_id) AS unique_customers
  FROM gold.fact_revenue f
  JOIN gold.dim_date d ON f.date_id = d.date_id
  JOIN gold.dim_product p ON f.product_id = p.product_id
  WHERE
    f.tenant_id = $1                          -- sempre filtrar por tenant primeiro
    AND d.year = $2                            -- usar coluna da dimensão, não TO_CHAR()
    AND d.month BETWEEN $3 AND $4
  GROUP BY d.year, d.month, p.product_category
)
SELECT
  *,
  ROUND(total_revenue_cents / 100.0, 2) AS total_revenue,
  SUM(total_revenue_cents) OVER (
    PARTITION BY year, month ORDER BY total_revenue_cents DESC
  ) AS cumulative_revenue
FROM monthly_revenue
ORDER BY year, month, total_revenue_cents DESC;

-- ERRADO: funções em colunas indexadas, full table scan inevitável
WHERE TO_CHAR(created_at, 'YYYY-MM') = '2024-01'  -- índice não será usado
WHERE LOWER(customer_email) = LOWER($1)             -- use functional index ou citext
```

### 5.2 Índices Estratégicos para Analytics

```sql
-- Índice composto obrigatório para queries multi-tenant
CREATE INDEX CONCURRENTLY idx_fact_revenue_tenant_date
  ON gold.fact_revenue (tenant_id, date_id, product_id)
  WHERE tenant_id IS NOT NULL;   -- partial index para performance

-- Índice para ordenação frequente
CREATE INDEX CONCURRENTLY idx_fact_revenue_tenant_amount
  ON gold.fact_revenue (tenant_id, revenue_cents DESC);

-- Índice covering para queries frequentes (evita heap fetch)
CREATE INDEX CONCURRENTLY idx_fact_revenue_covering
  ON gold.fact_revenue (tenant_id, date_id)
  INCLUDE (revenue_cents, customer_id, product_id);
```

### 5.3 Materialized Views para Agregações Pesadas

```sql
-- Criar materialized view para KPIs frequentes
CREATE MATERIALIZED VIEW gold.mv_daily_revenue_by_tenant AS
SELECT
  tenant_id,
  date_id,
  SUM(revenue_cents) AS total_revenue_cents,
  COUNT(*) AS transaction_count,
  COUNT(DISTINCT customer_id) AS unique_customers
FROM gold.fact_revenue
GROUP BY tenant_id, date_id;

CREATE UNIQUE INDEX ON gold.mv_daily_revenue_by_tenant (tenant_id, date_id);

-- Refresh automatizado via Airflow/dbt (NUNCA manual)
REFRESH MATERIALIZED VIEW CONCURRENTLY gold.mv_daily_revenue_by_tenant;
```

---

## 6. Segurança e Multi-Tenancy — Zero Trust

### 6.1 Row Level Security (RLS) Obrigatório

```sql
-- CERTO: RLS habilitado em todas as tabelas com dados de tenant
ALTER TABLE gold.fact_revenue ENABLE ROW LEVEL SECURITY;
ALTER TABLE gold.fact_revenue FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON gold.fact_revenue
  USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- No backend: SEMPRE setar o contexto antes de qualquer query
SET LOCAL app.current_tenant_id = '<tenant-uuid>';  -- SET LOCAL para escopo da transação apenas

-- ERRADO: filtrar tenant_id apenas na query sem RLS
SELECT * FROM gold.fact_revenue WHERE tenant_id = $1;  -- bypass possível por SQL injection
```

### 6.2 RBAC para Analytics

```
Roles de Analytics (hierarquia):
  viewer          → lê dashboards e relatórios pré-definidos
  analyst         → viewer + pode criar queries ad-hoc, exportar dados
  data_engineer   → analyst + pode gerenciar pipelines, criar modelos
  data_admin      → data_engineer + gerencia usuários, configura fontes de dados
  platform_admin  → data_admin + gerencia tenants, configurações globais
```

```sql
-- Implementar como roles PostgreSQL + policies RLS
CREATE ROLE analytics_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA gold TO analytics_viewer;
REVOKE SELECT ON gold.fact_pii_data FROM analytics_viewer;  -- PII protegido por padrão

-- NUNCA conceder acesso direto a schemas Bronze/Silver a roles de negócio
REVOKE ALL ON SCHEMA bronze FROM analytics_viewer;
REVOKE ALL ON SCHEMA bronze FROM analytics_analyst;
```

### 6.3 GDPR/LGPD Compliance

**Dados PII (Personally Identifiable Information)** — tratamento especial obrigatório:

```sql
-- Pseudoanonymização: usar hash + salt para dados PII em analytics
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Na camada Silver: substituir PII por hash pseudoanonimizado
SELECT
  encode(digest(email || $TENANT_SALT, 'sha256'), 'hex') AS email_hash,
  -- guardar email completo apenas em tabela de PII separada com acesso restrito
  LEFT(first_name, 1) || '***' AS display_name,  -- k-anonymity
  country_code,  -- OK para analytics
  created_at::DATE AS signup_date  -- granularidade reduzida
FROM staging.stg_users;
```

**Checklist GDPR obrigatório**:
- [ ] Mapa de dados (quais tabelas têm PII, onde estão armazenadas).
- [ ] Right to erasure implementado (soft delete + propagação a todas as tabelas).
- [ ] Data retention policy configurada (TTL automático por categoria de dado).
- [ ] Audit log de acesso a dados sensíveis.
- [ ] Data Processing Agreements (DPAs) com fornecedores de cloud.
- [ ] Consent tracking registrado antes de qualquer coleta.

---

## 7. Observabilidade de Dados — Data Quality + Lineage

### 7.1 Dimensões de Qualidade (Obrigatório monitorar todas)

| Dimensão | Métrica | Ferramenta |
|---|---|---|
| **Freshness** | `MAX(updated_at) < NOW() - INTERVAL '2h'` | Airflow, dbt tests |
| **Completeness** | `COUNT(NULL) / COUNT(*) > threshold` | Great Expectations, dbt |
| **Uniqueness** | `COUNT(*) != COUNT(DISTINCT pk)` | dbt unique test |
| **Accuracy** | `SUM(amount) != expected_total` | Reconciliation jobs |
| **Consistency** | `silver.count != gold.count` (sem filtros válidos) | Cross-layer checks |
| **Volume** | `COUNT(*) < p25 OR COUNT(*) > p75` (anomalia) | Anomaly detection |

```python
# CERTO: teste de qualidade com Great Expectations
import great_expectations as gx

context = gx.get_context()
suite = context.create_expectation_suite("gold.fact_revenue")

# Freshness
suite.add_expectation(gx.expectations.ExpectColumnMaxToBeBetween(
    column="created_at",
    min_value=datetime.now() - timedelta(hours=2),
    max_value=datetime.now(),
))

# Non-null critical fields
suite.add_expectation(gx.expectations.ExpectColumnValuesToNotBeNull(column="tenant_id"))
suite.add_expectation(gx.expectations.ExpectColumnValuesToNotBeNull(column="date_id"))

# Revenue sanity check
suite.add_expectation(gx.expectations.ExpectColumnValuesToBeBetween(
    column="revenue_cents",
    min_value=1,           # zero ou negativo é suspeito — investigar
    max_value=10_000_000_00,  # R$10M por transação — alerta para fraude
))
```

### 7.2 Data Lineage — Rastreabilidade

Toda pipeline DEVE emitir eventos OpenLineage para rastreabilidade:

```python
# Emitir eventos de lineage em cada pipeline run
from openlineage.client import OpenLineageClient
from openlineage.client.run import RunEvent, RunState, Job, Run, Dataset

client = OpenLineageClient.from_environment()

client.emit(RunEvent(
    eventType=RunState.START,
    eventTime=datetime.now().isoformat(),
    run=Run(runId=str(uuid4())),
    job=Job(namespace="airflow", name="ingest_stripe_payments"),
    inputs=[Dataset(namespace="stripe", name="payments")],
    outputs=[Dataset(namespace="postgres", name="bronze.raw_stripe_payments")],
))
```

---

## 8. Visualização de Dados — Front-End Analytics

### 8.1 Escolha de Biblioteca por Caso

| Library | Usar quando | Rendering |
|---|---|---|
| **Recharts** | Dashboards simples-médios, < 10k pontos | SVG |
| **Apache ECharts** | Grande volume de dados (>10k pontos), 3D, mapas, real-time | Canvas/WebGL |
| **D3.js** | Visualizações custom, não-padrão | SVG/Canvas/DOM |
| **Nivo** | React-nativo, acessível, boa DX | SVG/Canvas/HTML |
| **Visx** | Componentes baixo-nível + D3 + React | SVG |

**Regra de Ouro**: Para dashboards de Analytics com dados reais (>1k pontos), use **ECharts**. Canvas supera SVG significativamente em performance.

### 8.2 Padrões de Dashboard

```tsx
// CERTO: Chart component com loading, error e empty states obrigatórios
interface ChartWrapperProps {
  title: string;
  data: ChartData[];
  isLoading: boolean;
  error: Error | null;
}

function ChartWrapper({ title, data, isLoading, error }: ChartWrapperProps) {
  if (isLoading) return <ChartSkeleton />;          // sempre skeleton, nunca spinner
  if (error) return <ChartError error={error} />;   // erro explícito com retry
  if (data.length === 0) return <EmptyState />;     // empty state significativo

  return (
    <div className="chart-container" role="figure" aria-label={title}>
      <h3 id={`chart-title-${title.toLowerCase().replace(/\s/g, '-')}`}>{title}</h3>
      <EChartsReact
        option={buildChartOption(data)}
        style={{ height: '300px', width: '100%' }}
        opts={{ renderer: 'canvas' }}              // sempre Canvas para performance
      />
    </div>
  );
}

// ERRADO: chart sem estados de loading/error/empty
function BadChart({ data }) {
  return <EChartsReact option={buildOption(data)} />;  // falha silenciosa!
}
```

### 8.3 Performance de Dashboard

```tsx
// CERTO: virtualizar tabelas de dados grandes
import { useVirtualizer } from '@tanstack/react-virtual';

// CERTO: debounce em filtros que disparam queries
const debouncedFilter = useDebounce(filter, 300);

// CERTO: React.memo em componentes de chart que recebem mesmo data
const RevenueChart = React.memo(({ data, period }) => (
  <EChartsReact option={buildRevenueOption(data, period)} />
), (prev, next) => prev.data === next.data && prev.period === next.period);

// CERTO: WebSocket para real-time (não polling)
useEffect(() => {
  const ws = new WebSocket(`wss://api/live-metrics/${tenantId}`);
  ws.onmessage = (event) => {
    const metric = JSON.parse(event.data);
    setMetrics(prev => [...prev.slice(-100), metric]);  // manter janela máxima
  };
  return () => ws.close();
}, [tenantId]);

// ERRADO: polling para "real-time"
setInterval(() => fetchMetrics(), 1000);  // 1000 requests/min por usuário — NUNCA
```

### 8.4 Acessibilidade em Charts (WCAG 2.2 AA)

```tsx
// CERTO: acessibilidade obrigatória em visualizações
<figure role="figure" aria-labelledby="chart-title">
  <figcaption id="chart-title">Receita Mensal - Janeiro 2024</figcaption>
  <EChartsReact
    option={option}
    aria-label="Gráfico de barras mostrando receita de R$ 150.000 em Janeiro"
  />
  {/* Tabela de dados alternativa para screen readers */}
  <details>
    <summary>Ver dados em formato tabular</summary>
    <DataTable data={chartData} />
  </details>
</figure>
```

---

## 9. Estrutura de Projeto Analytics

```
analytics-platform/
├── ingestion/          # Conectores de fontes de dados
│   ├── stripe/
│   ├── salesforce/
│   └── webhooks/
├── pipelines/          # Airflow DAGs
│   ├── dags/
│   └── plugins/
├── transform/          # dbt project
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   ├── tests/
│   └── dbt_project.yml
├── streaming/          # Kafka consumers + Flink jobs
│   ├── consumers/
│   └── flink-jobs/
├── api/                # Analytics API (Rust/Axum ou FastAPI)
│   ├── routes/
│   ├── services/
│   └── dto/
├── frontend/           # Dashboard frontend (React + ECharts)
│   ├── components/charts/
│   ├── components/filters/
│   └── pages/
└── infra/
    ├── migrations/     # Schema migrations versionadas
    └── seeds/          # Dados de referência (dim_date, etc.)
```

---

## 10. Checklist de Qualidade Senior+

Antes de qualquer feature em analytics ir para produção:

- [ ] **Pipeline idempotente** — reexecutar não causa duplicatas.
- [ ] **Testes dbt** — unique, not_null, freshness, relationships.
- [ ] **RLS ativo** — tenant isolation testada explicitamente.
- [ ] **Índices compostos** — `(tenant_id, date_id)` em toda tabela de analytics.
- [ ] **Gold layer** — BI tools acessam apenas Gold, nunca Bronze/Silver.
- [ ] **SCD Type 2** — dimensões históricas com `valid_from/valid_to`.
- [ ] **DLQ configurada** — nenhuma mensagem perdida silenciosamente.
- [ ] **Data quality checks** — freshness, completeness, uniqueness, volume.
- [ ] **Lineage registrado** — todo pipeline emite OpenLineage events.
- [ ] **PII pseudoanonimizado** — dados pessoais nunca em Gold layer em claro.
- [ ] **EXPLAIN ANALYZE** — toda query nova rodada com EXPLAIN antes de deploy.
- [ ] **Surrogate keys** — nunca usar PKs operacionais como FKs no DW.
- [ ] **Empty/Error/Loading states** — todo chart tem os três estados obrigatórios.
- [ ] **Accessibility** — figcaption + tabela alternativa em todos os charts.
- [ ] **Audit log** — quem acessou quais dados, quando.
