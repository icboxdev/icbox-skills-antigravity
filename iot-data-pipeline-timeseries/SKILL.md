---
name: IoT Data Pipeline & Time-Series Architecture
description: Architect, validate, and optimize IoT data pipelines covering ingestion patterns (MQTT, HTTP batch), stream processing (Kafka, Flink), time-series databases (TimescaleDB, InfluxDB), data retention policies, downsampling strategies, and analytics architecture. Concept-focused, stack-agnostic.
---

# IoT Data Pipeline & Time-Series — Diretrizes Senior+

## 1. Princípio Fundamental

IoT gera dados em velocidade e volume que sistemas tradicionais não suportam. A arquitetura de dados DEVE ser projetada para **ingestão contínua, processamento em camadas, e retenção inteligente**.

> ⚠️ Armazenar TUDO em resolução máxima para SEMPRE é financeiramente insustentável. Data lifecycle management é obrigatório.

---

## 2. Anatomia do Pipeline IoT

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  INGEST  │───→│  BUFFER  │───→│ PROCESS  │───→│  STORE   │───→│ SERVE    │
│  MQTT    │    │  Kafka   │    │ Stream   │    │ TSDB     │    │ API/     │
│  HTTP    │    │  Redis   │    │ Filter   │    │ Cold     │    │ Dashboard│
│  CoAP    │    │  SQS     │    │ Aggregate│    │ Archive  │    │ Alerts   │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
      │              │              │              │              │
      └── Decouple ──┘── Decouple ──┘── Decouple ──┘── Decouple ──┘
```

**Regra**: Cada estágio DEVE ser **desacoplado** do anterior. Se o processamento parar, a ingestão NÃO pode parar.

---

## 3. Ingestão de Dados

### 3.1 Padrões de Ingestão

| Padrão | Latência | Volume | Quando Usar |
|---|---|---|---|
| **Event Streaming** | < 1s | Alto | Telemetria contínua, alertas |
| **Micro-Batch** | 1-60s | Alto | Agregação de leituras, stats |
| **Batch** | Minutos-horas | Muito alto | Analytics histórico, ML training |

### 3.2 Design de Ingestão

```
CERTO: Ingestão desacoplada com buffer
Device → MQTT Broker → Message Queue (Kafka/Redis) → Worker → Database
                            ↑
                     buffer protege contra picos
                     e falhas downstream

ERRADO: Ingestão síncrona acoplada
Device → HTTP POST → API → INSERT direto no banco
                              ↑
                    1000 devices × 1 msg/s = 1000 INSERT/s
                    banco para → dados PERDIDOS
```

### 3.3 Regras de Ingestão

- ✅ SEMPRE desacoplar ingestão de processamento (message queue no meio)
- ✅ SEMPRE validar schema na entrada (reject malformed data early)
- ✅ SEMPRE usar idempotency key (device_id + timestamp) para dedup
- ✅ SEMPRE comprimir payloads se > 1KB (gzip, protobuf, msgpack)
- ❌ NUNCA fazer INSERT síncrono no hot path de ingestão
- ❌ NUNCA confiar em dados sem validação de tipo e range

---

## 4. Stream Processing

### 4.1 Operações Comuns

| Operação | Descrição | Exemplo |
|---|---|---|
| **Filter** | Descartar dados inválidos | Remover leituras temp < -50°C |
| **Transform** | Converter formato/unidade | °F → °C, raw ADC → engenharia |
| **Aggregate** | Reduzir volume | Média de 60 pontos → 1/min |
| **Enrich** | Adicionar contexto | Juntar tenant info, sensor metadata |
| **Detect** | Identificar padrões | Anomalia se valor > 3σ do baseline |
| **Alert** | Disparar notificação | Se temp > 80°C → alarme SMS |

### 4.2 Windowing Strategies

```
Tumbling Window (fixa, sem overlap):
[0-60s] [60-120s] [120-180s] ...
→ Usar para: métricas por minuto/hora, billing

Sliding Window (móvel, com overlap):
[0-60s] [30-90s] [60-120s] ...
→ Usar para: detecção de tendência, moving average

Session Window (por atividade):
[evento1_início ... evento1_fim] [gap] [evento2...]
→ Usar para: sessões de uso, operações batch
```

---

## 5. Time-Series Databases

### 5.1 Comparativo

| Feature | **TimescaleDB** | **InfluxDB 3.x** | **QuestDB** |
|---|---|---|---|
| Base | PostgreSQL extension | Standalone (Rust) | Standalone (Java) |
| Query | SQL completo | InfluxQL / Flux / SQL | SQL |
| Schema | Typed (relational) | Schemaless (tags/fields) | Typed |
| Compressão | Alta (hypertables) | Muito alta (columnar) | Alta |
| Joins | ✅ SQL joins nativos | ❌ Limitado | ⚠️ Básico |
| High Cardinality | ✅ Forte | ⚠️ Cuidado | ✅ Forte |
| Ideal para | IoT + relacional | Métricas/observabilidade | Ultra-high ingest |

### 5.2 Regras de Seleção

```
Precisa de SQL completo + joins com dados relacionais?
  → TimescaleDB (PostgreSQL ecosystem)

Foco em métricas/observabilidade pura?
  → InfluxDB

Ultra-high ingest (> 1M rows/sec)?
  → QuestDB ou ClickHouse

Já usa PostgreSQL no projeto?
  → TimescaleDB (extensão, sem nova stack)
```

---

## 6. Data Retention & Downsampling

### 6.1 Estratégia por Camada

```
┌─────────────────────────────────────────────┐
│  HOT (0-7 dias)                             │
│  Resolução: Original (1s/5s)                │
│  Storage: SSD, hypertable sem compressão    │
│  Queries: Real-time dashboards, alertas     │
├─────────────────────────────────────────────┤
│  WARM (7-90 dias)                           │
│  Resolução: 1 minuto (downsampled)          │
│  Storage: HDD, compressão ativa             │
│  Queries: Trends, relatórios diarios        │
├─────────────────────────────────────────────┤
│  COLD (90-365 dias)                         │
│  Resolução: 1 hora (downsampled)            │
│  Storage: Object storage (S3), Parquet      │
│  Queries: Analytics anual, compliance       │
├─────────────────────────────────────────────┤
│  ARCHIVE (> 365 dias)                       │
│  Resolução: 1 dia (estatísticas)            │
│  Storage: Glacier/Deep Archive              │
│  Queries: Audit, regulatório (raro)         │
└─────────────────────────────────────────────┘
```

### 6.2 Downsampling Automatizado

```sql
-- Exemplo conceitual: Continuous Aggregate (TimescaleDB)
-- Cria view materializada que agrega automaticamente

CREATE MATERIALIZED VIEW readings_hourly
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', timestamp) AS bucket,
  sensor_id,
  AVG(value) AS avg_value,
  MIN(value) AS min_value,
  MAX(value) AS max_value,
  COUNT(*) AS sample_count
FROM readings_raw
GROUP BY bucket, sensor_id;

-- Retention policy: drop raw data after 7 days
SELECT add_retention_policy('readings_raw', INTERVAL '7 days');
```

---

## 7. Partitioning Strategies

### 7.1 Por Tempo (Obrigatório para TSDB)

```
readings_2025_03_01
readings_2025_03_02
readings_2025_03_03
...

→ Benefícios: DROP PARTITION é O(1) vs DELETE row-by-row
→ Query scan limitado ao range temporal
```

### 7.2 Por Tenant (Multi-tenant)

```
Opção A: Coluna tenant_id + partition by time (mais simples)
Opção B: Schema por tenant (isolação total, mais complexo)
Opção C: Database por tenant (máxima isolação, alto custo)

Recomendado para IoT: Opção A com índice composto (tenant_id, timestamp)
```

---

## 8. Dimensionamento

### 8.1 Fórmula de Volume

```
Volume diário = devices × sensors_per_device × samples_per_second × 86400 × bytes_per_sample

Exemplo:
  1000 devices × 5 sensors × 1 sample/10s × 86400s × 50 bytes
  = 1000 × 5 × 8640 × 50
  = 2.16 GB/dia
  = ~65 GB/mês (raw)
  = ~6.5 GB/mês (10:1 compressão)
```

### 8.2 Benchmarks de Referência

| Escala | Devices | Ingest Rate | Estratégia DB |
|---|---|---|---|
| Small | < 100 | < 1K msg/s | PostgreSQL single node |
| Medium | 100-1K | 1K-10K msg/s | TimescaleDB single node |
| Large | 1K-10K | 10K-100K msg/s | TimescaleDB multi-node ou Kafka + DB |
| Massive | 10K+ | > 100K msg/s | Kafka + ClickHouse/QuestDB cluster |

---

## 9. Dogmas

### NUNCA
- ❌ NUNCA fazer INSERT síncrono direto no hot path
- ❌ NUNCA armazenar dados de alta resolução indefinidamente
- ❌ NUNCA ignorar data validation na ingestão
- ❌ NUNCA usar banco relacional sem time-series otimization para telemetria
- ❌ NUNCA deletar dados row-by-row (usar DROP PARTITION)

### SEMPRE
- ✅ SEMPRE desacoplar ingest de processing com message queue
- ✅ SEMPRE definir retention policy antes de ir para produção
- ✅ SEMPRE implementar downsampling automatizado (continuous aggregates)
- ✅ SEMPRE usar idempotency key para deduplicação
- ✅ SEMPRE monitorar ingest lag e queue depth
- ✅ SEMPRE particionar por tempo (mínimo: diário)
