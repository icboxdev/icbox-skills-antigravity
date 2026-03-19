---
name: Real-Time Data Monitoring Engineering
description: Architect, generate, validate, and optimize real-time data monitoring platforms. Covers streaming architecture (WebSocket, SSE, pub/sub), time-series storage (TimescaleDB, continuous aggregates, retention policies), alerting system (threshold rules, anomaly detection, severity escalation, notification channels), live dashboard rendering (ECharts Canvas, circular buffer, downsampling LTTB), connection health indicators, and Rust backend (Axum WebSocket, broadcast channels, Tokio intervals).
---

# Real-Time Data Monitoring Engineering — Diretrizes Senior+

## 0. Princípio Fundamental: Monitor Para Agir, Não Para Assistir

Um sistema de monitoramento em tempo real não é TV ligada — é um **sistema de alerta precoce**:
- Todo dado em tempo real DEVE ter: threshold definido, ação esperada quando violado, e responsável notificado.
- Dado sem threshold = dashboard decorativo. Ação sem alerta = tempo desperdiçado.
- **Regra**: se ninguém vai agir quando o valor muda, ele NÃO precisa ser real-time.

> ⚠️ **Crime Arquitetural**: Enviar 100 métricas por segundo via WebSocket sem que nenhuma tenha threshold configurado. Real-time tem custo — justifique cada métrica.

---

## 1. Arquitetura de Monitoramento Real-Time

### 1.1 Fluxo Completo

```
[Data Source]       [Rust Backend (Axum)]                     [React Frontend]
     │                     │                                        │
     ├─ Sensor/API ──────► │ Ingest Endpoint                      │
     │  POST /ingest       │   → Validate + Persist (TimescaleDB) │
     │                     │   → Evaluate Alert Rules              │
     │                     │   → Broadcast via Channel             │
     │                     │        │                               │
     │                     │        ├── WebSocket Hub ──────────► │ Live Dashboard
     │                     │        │   (per-tenant broadcast)     │   (ECharts streaming)
     │                     │        │                               │
     │                     │        ├── Alert Engine ──────────► │ Alert Panel
     │                     │        │   threshold / anomaly        │   (severity badges)
     │                     │        │                               │
     │                     │        └── SSE (lightweight) ─────► │ Status Indicators
     │                     │            (connection health)        │   (pulsing dots)
     │                     │                                        │
     └─ Periodic Pull ──► │ Polling Service                       │
        (SNMP, HTTP)       │   → tokio::interval                   │
```

### 1.2 Escolha de Transport

| Transport | Quando Usar | Trade-off |
|---|---|---|
| **WebSocket** | Dashboard live, dados em alta frequência (>1 msg/s) | Bidirecional, persistent. Mais complexo de gerenciar. |
| **SSE** | Notificações, status updates, logs em stream | Unidirecional, auto-reconnect, sem overhead de client. |
| **Polling** | Métricas lentas (>30s interval), fallback | Simples, sem estado. Desperdiça requests se nada mudou. |

**Dogma**: Dashboard de monitoramento real-time usa **WebSocket**. Status/heartbeat usa **SSE**. NUNCA use polling para dados < 30s de intervalo.

---

## 2. Backend Rust — Ingest, Broadcast, Alert

### 2.1 Ingest Endpoint com Validação

```rust
// CERTO: ingest endpoint com validação, persistência e broadcast
use axum::{extract::{State, Json}, http::StatusCode};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Deserialize, Serialize)]
struct DataPoint {
    metric: String,           // "cpu_usage", "temperature", "revenue"
    value: f64,
    #[serde(default = "Utc::now")]
    timestamp: DateTime<Utc>,
    tags: Option<HashMap<String, String>>,  // {"host": "srv-01", "region": "us-east"}
    source_id: Uuid,           // dispositivo ou sistema de origem
}

#[derive(Debug, Deserialize)]
struct IngestBatch {
    points: Vec<DataPoint>,    // batch de pontos — NUNCA 1 request por ponto
}

async fn ingest(
    State(state): State<AppState>,
    tenant: TenantContext,
    Json(batch): Json<IngestBatch>,
) -> Result<StatusCode, ApiError> {
    // 1. Validar tamanho do batch (max 1000 pontos por request)
    if batch.points.len() > 1000 {
        return Err(ApiError::validation("Batch excede 1000 pontos"));
    }

    // 2. Persistir em TimescaleDB (bulk insert)
    persist_data_points(&state.db, &tenant, &batch.points).await?;

    // 3. Avaliar regras de alerta contra os novos pontos
    let alerts = evaluate_alert_rules(&state, &tenant, &batch.points).await?;
    if !alerts.is_empty() {
        process_alerts(&state, &tenant, alerts).await?;
    }

    // 4. Broadcast para clientes WebSocket conectados (por tenant)
    let _ = state.ws_broadcast
        .get(&tenant.id)
        .map(|tx| tx.send(WsMessage::DataPoints(batch.points.clone())));

    Ok(StatusCode::NO_CONTENT)
}

// CERTO: bulk insert preparado para TimescaleDB hypertable
async fn persist_data_points(
    db: &PgPool,
    tenant: &TenantContext,
    points: &[DataPoint],
) -> Result<(), sqlx::Error> {
    // Prepared statement com UNNEST para bulk insert eficiente
    sqlx::query!(
        r#"
        INSERT INTO metrics (tenant_id, metric, value, timestamp, source_id, tags)
        SELECT $1, * FROM UNNEST($2::text[], $3::float8[], $4::timestamptz[], $5::uuid[], $6::jsonb[])
        "#,
        tenant.id,
        &points.iter().map(|p| p.metric.clone()).collect::<Vec<_>>(),
        &points.iter().map(|p| p.value).collect::<Vec<_>>(),
        &points.iter().map(|p| p.timestamp).collect::<Vec<_>>(),
        &points.iter().map(|p| p.source_id).collect::<Vec<_>>(),
        &points.iter().map(|p| serde_json::to_value(&p.tags).unwrap_or_default()).collect::<Vec<_>>(),
    )
    .execute(db)
    .await?;

    Ok(())
}

// ERRADO: 1 INSERT por ponto, sem batch
for point in &batch.points {
    sqlx::query!("INSERT INTO metrics (...) VALUES (...)", ...).execute(db).await?;
    // N queries = N round trips = LENTO em alta frequência
}
```

### 2.2 WebSocket Hub — Broadcast por Tenant

```rust
// CERTO: WebSocket hub com broadcast channels por tenant
use axum::extract::ws::{WebSocket, WebSocketUpgrade, Message};
use tokio::sync::broadcast;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

type TenantChannels = Arc<RwLock<HashMap<Uuid, broadcast::Sender<WsMessage>>>>;

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", content = "payload")]
enum WsMessage {
    DataPoints(Vec<DataPoint>),
    Alert(AlertNotification),
    ConnectionStatus { connected_clients: usize },
    Heartbeat,
}

/// Inicializar broadcast channel para um tenant (lazy)
async fn get_or_create_channel(
    channels: &TenantChannels,
    tenant_id: Uuid,
) -> broadcast::Sender<WsMessage> {
    let read = channels.read().await;
    if let Some(tx) = read.get(&tenant_id) {
        return tx.clone();
    }
    drop(read);

    let mut write = channels.write().await;
    // Double-check após adquirir write lock
    write.entry(tenant_id)
        .or_insert_with(|| {
            let (tx, _) = broadcast::channel(256);  // buffer de 256 mensagens
            tx
        })
        .clone()
}

/// WebSocket handler — cada cliente se inscreve no canal do seu tenant
async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
    tenant: TenantContext,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_ws_connection(socket, state, tenant))
}

async fn handle_ws_connection(
    mut socket: WebSocket,
    state: AppState,
    tenant: TenantContext,
) {
    let tx = get_or_create_channel(&state.ws_channels, tenant.id).await;
    let mut rx = tx.subscribe();

    // Heartbeat ticker — 30s interval
    let mut heartbeat = tokio::time::interval(Duration::from_secs(30));

    loop {
        tokio::select! {
            // Broadcast message recebida → enviar para o cliente
            msg = rx.recv() => {
                match msg {
                    Ok(ws_msg) => {
                        let json = serde_json::to_string(&ws_msg).unwrap();
                        if socket.send(Message::Text(json)).await.is_err() {
                            break;  // cliente desconectou
                        }
                    }
                    Err(broadcast::error::RecvError::Lagged(n)) => {
                        tracing::warn!(tenant = %tenant.id, lagged = n, "Client lagging — messages dropped");
                        // Cliente lento — enviar aviso
                        let _ = socket.send(Message::Text(
                            r#"{"type":"warning","payload":"Messages dropped due to slow connection"}"#.into()
                        )).await;
                    }
                    Err(_) => break,
                }
            }

            // Heartbeat — manter conexão viva
            _ = heartbeat.tick() => {
                let msg = serde_json::to_string(&WsMessage::Heartbeat).unwrap();
                if socket.send(Message::Text(msg)).await.is_err() {
                    break;
                }
            }

            // Cliente enviou mensagem (subscription filters, ping)
            msg = socket.recv() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        // Processar subscription filters (quais métricas o client quer)
                        handle_client_message(&text).ok();
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    _ => {}
                }
            }
        }
    }

    tracing::info!(tenant = %tenant.id, "WebSocket client disconnected");
}

// ERRADO: criar nova conexão de banco por mensagem WebSocket
// ERRADO: não ter heartbeat — conexão morre silenciosamente
// ERRADO: broadcast sem buffer — perde mensagens quando cliente é lento
```

### 2.3 SSE — Para Status e Notificações Leves

```rust
// CERTO: SSE endpoint para status e notificações (mais leve que WebSocket)
use axum::response::sse::{Event, Sse};
use futures::stream::Stream;

async fn sse_status(
    State(state): State<AppState>,
    tenant: TenantContext,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let tx = get_or_create_channel(&state.ws_channels, tenant.id).await;
    let mut rx = tx.subscribe();

    let stream = async_stream::stream! {
        // Enviar snapshot inicial
        let status = get_system_status(&state, &tenant).await;
        yield Ok(Event::default()
            .event("status")
            .data(serde_json::to_string(&status).unwrap()));

        // Stream de updates
        loop {
            match rx.recv().await {
                Ok(WsMessage::Alert(alert)) => {
                    yield Ok(Event::default()
                        .event("alert")
                        .data(serde_json::to_string(&alert).unwrap()));
                }
                Ok(WsMessage::ConnectionStatus { connected_clients }) => {
                    yield Ok(Event::default()
                        .event("connection")
                        .data(format!(r#"{{"connected":{}}}"#, connected_clients)));
                }
                Ok(WsMessage::Heartbeat) => {
                    yield Ok(Event::default().comment("heartbeat"));
                }
                _ => {}
            }
        }
    };

    Sse::new(stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("keepalive")
    )
}
```

---

## 3. Time-Series Storage — TimescaleDB

### 3.1 Schema com Hypertable e Continuous Aggregates

```sql
-- CERTO: TimescaleDB schema otimizado para monitoramento real-time

-- Extensão TimescaleDB
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Tabela principal de métricas (convertida em hypertable)
CREATE TABLE metrics (
    tenant_id    UUID NOT NULL,
    metric       TEXT NOT NULL,
    value        DOUBLE PRECISION NOT NULL,
    timestamp    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source_id    UUID NOT NULL,
    tags         JSONB DEFAULT '{}',
    -- Não usar PK auto-increment — time-series não precisa
    CONSTRAINT metrics_tenant_fk FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);

-- Converter em hypertable (particiona por tempo automaticamente)
SELECT create_hypertable('metrics', 'timestamp',
    chunk_time_interval => INTERVAL '1 day',    -- 1 chunk por dia
    if_not_exists => TRUE
);

-- Índices essenciais
CREATE INDEX idx_metrics_tenant_metric_time
    ON metrics (tenant_id, metric, timestamp DESC);

CREATE INDEX idx_metrics_source_time
    ON metrics (tenant_id, source_id, timestamp DESC);

-- Índice GIN para tags JSONB
CREATE INDEX idx_metrics_tags ON metrics USING GIN (tags);

-- Compressão automática (chunks > 7 dias são comprimidos)
ALTER TABLE metrics SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'tenant_id, metric, source_id',
    timescaledb.compress_orderby = 'timestamp DESC'
);
SELECT add_compression_policy('metrics', INTERVAL '7 days');

-- CONTINUOUS AGGREGATE: médias por minuto (pré-calculado)
CREATE MATERIALIZED VIEW metrics_1m
WITH (timescaledb.continuous) AS
SELECT
    tenant_id,
    metric,
    source_id,
    time_bucket('1 minute', timestamp) AS bucket,
    AVG(value)   AS avg_value,
    MIN(value)   AS min_value,
    MAX(value)   AS max_value,
    COUNT(*)     AS sample_count
FROM metrics
GROUP BY tenant_id, metric, source_id, bucket
WITH NO DATA;

-- Refresh policy: atualiza a cada 1 minuto
SELECT add_continuous_aggregate_policy('metrics_1m',
    start_offset    => INTERVAL '5 minutes',
    end_offset      => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute'
);

-- CONTINUOUS AGGREGATE: médias por hora
CREATE MATERIALIZED VIEW metrics_1h
WITH (timescaledb.continuous) AS
SELECT
    tenant_id,
    metric,
    source_id,
    time_bucket('1 hour', timestamp) AS bucket,
    AVG(value)   AS avg_value,
    MIN(value)   AS min_value,
    MAX(value)   AS max_value,
    COUNT(*)     AS sample_count
FROM metrics
GROUP BY tenant_id, metric, source_id, bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('metrics_1h',
    start_offset    => INTERVAL '2 hours',
    end_offset      => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Retention policy: dados brutos = 30 dias, 1m = 90 dias, 1h = 2 anos
SELECT add_retention_policy('metrics', INTERVAL '30 days');
SELECT add_retention_policy('metrics_1m', INTERVAL '90 days');
-- metrics_1h: sem retention (dados agregados por hora são leves)
```

### 3.2 Query Tiered — Resolução Automática

```rust
// CERTO: selecionar tabela baseada no range de tempo solicitado
fn select_metrics_table(time_range: &TimeRange) -> &'static str {
    let duration = time_range.end - time_range.start;
    match duration {
        d if d <= Duration::hours(6)  => "metrics",       // dados brutos — últimas 6h
        d if d <= Duration::days(7)   => "metrics_1m",    // agregado por minuto — última semana
        _                             => "metrics_1h",    // agregado por hora — períodos longos
    }
}

/// Query adaptativa que escolhe a resolução certa
async fn query_metrics(
    db: &PgPool,
    tenant_id: Uuid,
    metric: &str,
    range: &TimeRange,
) -> Result<Vec<MetricPoint>, sqlx::Error> {
    let table = select_metrics_table(range);

    // Query dinâmica baseada na resolução
    let query = format!(
        r#"
        SELECT
            bucket AS timestamp,
            avg_value AS value,
            min_value,
            max_value,
            sample_count
        FROM {table}
        WHERE tenant_id = $1
          AND metric = $2
          AND bucket >= $3
          AND bucket <= $4
        ORDER BY bucket ASC
        "#
    );

    sqlx::query_as::<_, MetricPoint>(&query)
        .bind(tenant_id)
        .bind(metric)
        .bind(range.start)
        .bind(range.end)
        .fetch_all(db)
        .await
}

// ERRADO: sempre ler dados brutos independente do range
// Query de 1 ano na tabela bruta = 31M+ rows = timeout
```

---

## 4. Alerting System — Regras, Avaliação, Escalação

### 4.1 Alert Rule Definition

```rust
// CERTO: alert rules tipadas com avaliação programática
#[derive(Debug, Deserialize, Serialize, sqlx::FromRow)]
struct AlertRule {
    id: Uuid,
    tenant_id: Uuid,
    name: String,
    metric: String,                    // "cpu_usage"
    source_filter: Option<Uuid>,       // NULL = todas as fontes
    condition: AlertCondition,
    severity: AlertSeverity,
    cooldown_seconds: i32,             // 300 = re-alerta após 5 min
    notification_channels: Vec<String>, // ["email", "slack", "webhook"]
    is_active: bool,
    last_triggered_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(tag = "type")]
enum AlertCondition {
    /// Valor ultrapassa threshold fixo
    Threshold {
        operator: ThresholdOperator,   // gt, lt, gte, lte, eq
        value: f64,
        #[serde(default = "default_consecutive")]
        consecutive_points: u32,       // alertar após N pontos consecutivos violando
    },
    /// Variação percentual em relação à média
    RateOfChange {
        percentage: f64,               // 20.0 = mudança de 20%
        window_seconds: i64,           // janela de comparação
    },
    /// Ausência de dados (source parou de enviar)
    Absence {
        timeout_seconds: i64,          // 300 = alertar se sem dados por 5 min
    },
    /// Anomalia estatística (desvio do baseline)
    Anomaly {
        sensitivity: f64,              // número de desvios padrão (2.0, 3.0)
        baseline_window: String,       // "7d" = baseline dos últimos 7 dias
    },
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
enum AlertSeverity {
    Info,       // log + dashboard badge
    Warning,    // email + slack
    Critical,   // SMS + phone + pager + auto-escalate
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
enum ThresholdOperator {
    Gt, Lt, Gte, Lte, Eq,
}
```

### 4.2 Avaliação de Regras

```rust
// CERTO: avaliar regras contra pontos recebidos com cooldown e dedup
async fn evaluate_alert_rules(
    state: &AppState,
    tenant: &TenantContext,
    points: &[DataPoint],
) -> Result<Vec<AlertNotification>, ApiError> {
    let rules = get_active_rules(&state.db, tenant.id).await?;
    let mut alerts = Vec::new();

    for rule in &rules {
        // Filtrar pontos relevantes para esta regra
        let relevant: Vec<&DataPoint> = points.iter()
            .filter(|p| p.metric == rule.metric)
            .filter(|p| rule.source_filter.map_or(true, |s| p.source_id == s))
            .collect();

        if relevant.is_empty() { continue; }

        // Verificar cooldown (evitar spam de alertas)
        if let Some(last) = rule.last_triggered_at {
            let elapsed = Utc::now() - last;
            if elapsed.num_seconds() < rule.cooldown_seconds as i64 {
                continue; // em cooldown — não re-alertar
            }
        }

        // Avaliar condição
        let triggered = match &rule.condition {
            AlertCondition::Threshold { operator, value, consecutive_points } => {
                evaluate_threshold(&relevant, operator, *value, *consecutive_points)
            }
            AlertCondition::RateOfChange { percentage, window_seconds } => {
                evaluate_rate_of_change(&state.db, tenant, &rule.metric, *percentage, *window_seconds).await?
            }
            AlertCondition::Absence { timeout_seconds } => {
                // Avaliado por job separado, não no ingest
                false
            }
            AlertCondition::Anomaly { sensitivity, baseline_window } => {
                evaluate_anomaly(&state.db, tenant, &rule.metric, &relevant, *sensitivity, baseline_window).await?
            }
        };

        if triggered {
            let notification = AlertNotification {
                id: Uuid::new_v4(),
                rule_id: rule.id,
                rule_name: rule.name.clone(),
                metric: rule.metric.clone(),
                severity: rule.severity.clone(),
                value: relevant.last().map(|p| p.value).unwrap_or(0.0),
                message: format_alert_message(rule, relevant.last().unwrap()),
                triggered_at: Utc::now(),
                acknowledged: false,
            };
            alerts.push(notification);

            // Atualizar last_triggered_at
            update_last_triggered(&state.db, rule.id).await?;
        }
    }

    Ok(alerts)
}

fn evaluate_threshold(
    points: &[&DataPoint],
    operator: &ThresholdOperator,
    threshold: f64,
    consecutive: u32,
) -> bool {
    let violations: usize = points.iter()
        .rev()         // mais recentes primeiro
        .take(consecutive as usize)
        .filter(|p| match operator {
            ThresholdOperator::Gt  => p.value > threshold,
            ThresholdOperator::Lt  => p.value < threshold,
            ThresholdOperator::Gte => p.value >= threshold,
            ThresholdOperator::Lte => p.value <= threshold,
            ThresholdOperator::Eq  => (p.value - threshold).abs() < f64::EPSILON,
        })
        .count();

    violations >= consecutive as usize
}
```

### 4.3 Notification Dispatcher

```rust
// CERTO: dispatcher multi-canal com retry e logging
async fn process_alerts(
    state: &AppState,
    tenant: &TenantContext,
    alerts: Vec<AlertNotification>,
) -> Result<(), ApiError> {
    for alert in &alerts {
        let rule = get_rule(&state.db, alert.rule_id).await?;

        // Persistir alerta no banco
        persist_alert(&state.db, tenant, alert).await?;

        // Broadcast para WebSocket (alerta aparece no dashboard)
        let _ = state.ws_broadcast
            .get(&tenant.id)
            .map(|tx| tx.send(WsMessage::Alert(alert.clone())));

        // Despachar para canais configurados
        for channel in &rule.notification_channels {
            let result = match channel.as_str() {
                "email" => send_email_alert(state, tenant, alert).await,
                "slack" => send_slack_alert(state, tenant, alert).await,
                "webhook" => send_webhook_alert(state, tenant, alert).await,
                "sms" => {
                    // SMS apenas para Critical
                    if matches!(alert.severity, AlertSeverity::Critical) {
                        send_sms_alert(state, tenant, alert).await
                    } else { Ok(()) }
                }
                _ => {
                    tracing::warn!(channel = %channel, "Unknown notification channel");
                    Ok(())
                }
            };

            if let Err(e) = result {
                tracing::error!(
                    channel = %channel,
                    alert_id = %alert.id,
                    error = %e,
                    "Failed to deliver alert notification"
                );
                // Não falhar — continuar com próximos canais
            }
        }
    }
    Ok(())
}
```

---

## 5. Frontend React — Live Dashboard

### 5.1 WebSocket Hook com Reconnect

```tsx
// CERTO: hook WebSocket com auto-reconnect, backoff, e message typing
type WsMessageHandler = (message: WsMessage) => void;

interface UseWebSocketOptions {
  url: string;
  onMessage: WsMessageHandler;
  maxRetries?: number;
  enabled?: boolean;
}

function useRealtimeWebSocket({ url, onMessage, maxRetries = 10, enabled = true }: UseWebSocketOptions) {
  const wsRef = useRef<WebSocket | null>(null);
  const retriesRef = useRef(0);
  const [status, setStatus] = useState<'connecting' | 'connected' | 'disconnected'>('disconnected');

  const connect = useCallback(() => {
    if (!enabled) return;

    setStatus('connecting');
    const ws = new WebSocket(url);

    ws.onopen = () => {
      setStatus('connected');
      retriesRef.current = 0;  // reset retries on successful connect
    };

    ws.onmessage = (event) => {
      try {
        const parsed = JSON.parse(event.data) as WsMessage;
        onMessage(parsed);
      } catch (e) {
        console.error('Failed to parse WS message:', e);
      }
    };

    ws.onclose = (event) => {
      setStatus('disconnected');
      wsRef.current = null;

      // Auto-reconnect com exponential backoff
      if (retriesRef.current < maxRetries && !event.wasClean) {
        const delay = Math.min(1000 * Math.pow(2, retriesRef.current), 30000);
        retriesRef.current += 1;
        setTimeout(connect, delay);
      }
    };

    ws.onerror = () => {
      ws.close();  // vai triggerar onclose → reconnect
    };

    wsRef.current = ws;
  }, [url, onMessage, maxRetries, enabled]);

  useEffect(() => {
    connect();
    return () => { wsRef.current?.close(1000, 'Component unmounted'); };
  }, [connect]);

  return { status, reconnect: connect };
}

// ERRADO: WebSocket sem reconnect — conexão morre e dashboard congela
```

### 5.2 Streaming Chart com Circular Buffer

```tsx
// CERTO: ECharts streaming com circular buffer e requestAnimationFrame
const MAX_POINTS = 300;  // manter apenas 300 pontos no gráfico (5 min a 1/s)

interface StreamingChartProps {
  metric: string;
  title: string;
  unit?: string;
  threshold?: number;
}

function StreamingChart({ metric, title, unit = '', threshold }: StreamingChartProps) {
  const chartRef = useRef<ReactECharts | null>(null);
  const dataRef = useRef<{ time: string; value: number }[]>([]);
  const rafRef = useRef<number | null>(null);
  const pendingUpdatesRef = useRef<DataPoint[]>([]);

  // Processar mensagens WebSocket
  const handleMessage = useCallback((msg: WsMessage) => {
    if (msg.type !== 'data_points') return;
    const relevant = msg.payload.filter((p: DataPoint) => p.metric === metric);
    if (relevant.length === 0) return;

    pendingUpdatesRef.current.push(...relevant);

    // Agendar atualização no próximo frame — evita multiple re-renders
    if (!rafRef.current) {
      rafRef.current = requestAnimationFrame(() => {
        flushUpdates();
        rafRef.current = null;
      });
    }
  }, [metric]);

  const flushUpdates = useCallback(() => {
    const updates = pendingUpdatesRef.current;
    pendingUpdatesRef.current = [];
    if (updates.length === 0) return;

    const buffer = dataRef.current;

    // Append novos pontos
    for (const point of updates) {
      buffer.push({
        time: new Date(point.timestamp).toLocaleTimeString('pt-BR'),
        value: point.value,
      });
    }

    // Circular buffer — remover pontos antigos
    while (buffer.length > MAX_POINTS) {
      buffer.shift();
    }

    // Atualizar ECharts sem re-render React
    const chart = chartRef.current?.getEchartsInstance();
    if (chart) {
      chart.setOption({
        xAxis: { data: buffer.map(d => d.time) },
        series: [{ data: buffer.map(d => d.value) }],
      });
    }
  }, []);

  useRealtimeWebSocket({
    url: `wss://api/ws/live`,
    onMessage: handleMessage,
  });

  const option: EChartsOption = useMemo(() => ({
    tooltip: { trigger: 'axis' },
    grid: { left: 48, right: 16, top: 32, bottom: 24 },
    xAxis: {
      type: 'category',
      data: [],
      axisLabel: { fontSize: 10, color: '#888' },
    },
    yAxis: {
      type: 'value',
      axisLabel: { fontSize: 10, color: '#888', formatter: `{value}${unit}` },
      splitLine: { lineStyle: { color: '#1a1a1d', type: 'dashed' } },
    },
    series: [
      {
        type: 'line',
        data: [],
        smooth: true,
        symbol: 'none',
        lineStyle: { width: 2, color: '#38bdf8' },
        areaStyle: {
          color: { type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(56,189,248,0.15)' },
              { offset: 1, color: 'rgba(56,189,248,0.01)' },
            ],
          },
        },
        animation: false,  // DESABILITAR animação em streaming — gera jank
      },
      // Threshold markLine
      ...(threshold ? [{
        type: 'line' as const,
        markLine: {
          silent: true,
          data: [{ yAxis: threshold, label: { formatter: `Limite: ${threshold}${unit}` } }],
          lineStyle: { color: '#ef4444', type: 'dashed' as const },
        },
        data: [],
      }] : []),
    ],
  }), [unit, threshold]);

  return (
    <div className="streaming-chart">
      <div className="chart-header">
        <h3 className="text-sm font-medium">{title}</h3>
        <LiveIndicator />
      </div>
      <ReactECharts
        ref={chartRef}
        option={option}
        style={{ height: '200px', width: '100%' }}
        opts={{ renderer: 'canvas' }}
        notMerge={false}   // merge incremental — NÃO recriar option inteira
      />
    </div>
  );
}

// ERRADO: atualizar state React a cada mensagem WebSocket
// setState → re-render → recria ECharts option → 60 re-renders/s → EXPLOSION
```

### 5.3 Connection Status Indicator

```tsx
// CERTO: indicador de conexão com pulsing dot (vivo/morto)
function ConnectionIndicator({ status }: { status: 'connecting' | 'connected' | 'disconnected' }) {
  return (
    <div className="flex items-center gap-2" role="status" aria-live="polite">
      <span
        className={cn(
          'size-2 rounded-full',
          status === 'connected' && 'bg-emerald-500 animate-pulse',
          status === 'connecting' && 'bg-amber-500 animate-pulse',
          status === 'disconnected' && 'bg-red-500',
        )}
        aria-hidden="true"
      />
      <span className="text-xs text-muted-foreground">
        {status === 'connected' && 'Ao vivo'}
        {status === 'connecting' && 'Reconectando...'}
        {status === 'disconnected' && 'Desconectado'}
      </span>
    </div>
  );
}

// CERTO: Live indicator com animação de pulso para gráficos streaming
function LiveIndicator() {
  return (
    <div className="flex items-center gap-1.5">
      <span className="relative flex size-2">
        <span className="absolute inline-flex size-full animate-ping rounded-full bg-red-400 opacity-75" />
        <span className="relative inline-flex size-2 rounded-full bg-red-500" />
      </span>
      <span className="text-[10px] font-medium text-red-500 uppercase tracking-wider">Live</span>
    </div>
  );
}
```

### 5.4 Alert Panel

```tsx
// CERTO: painel de alertas com severity badges e ack
function AlertPanel() {
  const alerts = useRealtimeAlerts();  // alimentado por WebSocket

  return (
    <div className="alert-panel" role="log" aria-label="Alertas ativos">
      {alerts.length === 0 ? (
        <div className="text-center text-muted-foreground py-8">
          <CheckCircleIcon className="size-8 mx-auto mb-2 text-emerald-500" />
          <p className="text-sm">Todos os sistemas operacionais</p>
        </div>
      ) : (
        <div className="space-y-2">
          {alerts.map((alert) => (
            <AlertCard key={alert.id} alert={alert} />
          ))}
        </div>
      )}
    </div>
  );
}

function AlertCard({ alert }: { alert: AlertNotification }) {
  const ackMutation = useMutation({
    mutationFn: () => alertService.acknowledge(alert.id),
  });

  return (
    <div className={cn(
      'alert-card p-3 rounded-lg border-l-4',
      alert.severity === 'critical' && 'border-l-red-500 bg-red-500/5',
      alert.severity === 'warning' && 'border-l-amber-500 bg-amber-500/5',
      alert.severity === 'info' && 'border-l-blue-500 bg-blue-500/5',
    )}>
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-2">
            <SeverityBadge severity={alert.severity} />
            <span className="text-sm font-medium">{alert.rule_name}</span>
          </div>
          <p className="text-xs text-muted-foreground mt-1">{alert.message}</p>
          <time className="text-[10px] text-muted-foreground">
            {formatDistanceToNow(alert.triggered_at, { locale: ptBR, addSuffix: true })}
          </time>
        </div>
        {!alert.acknowledged && (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => ackMutation.mutate()}
            disabled={ackMutation.isPending}
          >
            Reconhecer
          </Button>
        )}
      </div>
    </div>
  );
}

function SeverityBadge({ severity }: { severity: AlertSeverity }) {
  return (
    <span className={cn(
      'inline-flex items-center px-1.5 py-0.5 rounded-full text-[10px] font-medium uppercase',
      severity === 'critical' && 'bg-red-500/10 text-red-500',
      severity === 'warning' && 'bg-amber-500/10 text-amber-500',
      severity === 'info' && 'bg-blue-500/10 text-blue-500',
    )}>
      {severity === 'critical' ? '🔴' : severity === 'warning' ? '🟡' : 'ℹ️'} {severity}
    </span>
  );
}
```

---

## 6. Performance — Regras Absolutas

### 6.1 Downsampling LTTB no Backend

```rust
// CERTO: downsampling com LTTB antes de enviar dados históricos para o frontend
/// Largest Triangle Three Buckets — preserva forma visual com menos pontos
fn lttb_downsample(data: &[(f64, f64)], target_points: usize) -> Vec<(f64, f64)> {
    if data.len() <= target_points { return data.to_vec(); }

    let bucket_size = (data.len() - 2) as f64 / (target_points - 2) as f64;
    let mut result = Vec::with_capacity(target_points);

    // Primeiro ponto sempre incluído
    result.push(data[0]);

    for i in 0..(target_points - 2) {
        let avg_start = ((i + 1) as f64 * bucket_size + 1.0) as usize;
        let avg_end = (((i + 2) as f64 * bucket_size + 1.0) as usize).min(data.len());

        // Média do próximo bucket (para calcular triângulo)
        let avg_x: f64 = data[avg_start..avg_end].iter().map(|p| p.0).sum::<f64>()
            / (avg_end - avg_start) as f64;
        let avg_y: f64 = data[avg_start..avg_end].iter().map(|p| p.1).sum::<f64>()
            / (avg_end - avg_start) as f64;

        // Bucket atual
        let range_start = (i as f64 * bucket_size + 1.0) as usize;
        let range_end = ((i + 1) as f64 * bucket_size + 1.0) as usize;

        let prev = result.last().unwrap();

        // Selecionar ponto que forma maior triângulo
        let mut max_area = -1.0f64;
        let mut selected = range_start;

        for j in range_start..range_end {
            let area = ((prev.0 - avg_x) * (data[j].1 - prev.1)
                - (prev.0 - data[j].0) * (avg_y - prev.1)).abs();
            if area > max_area {
                max_area = area;
                selected = j;
            }
        }

        result.push(data[selected]);
    }

    // Último ponto sempre incluído
    result.push(*data.last().unwrap());
    result
}

// Uso: nunca enviar > 2000 pontos para o frontend
let raw = query_metrics(db, tenant_id, metric, range).await?;
let downsampled = lttb_downsample(&raw, 1000);  // max 1000 pontos para o gráfico
```

### 6.2 Regras de Rendering

```
┌────────────────────────────┬────────────────────────────┐
│ Cenário                    │ Estratégia                 │
├────────────────────────────┼────────────────────────────┤
│ Streaming chart (live)     │ requestAnimationFrame      │
│                            │ animation: false           │
│                            │ Canvas renderer            │
│                            │ update via chart instance   │
│                            │ NÃO via React state        │
├────────────────────────────┼────────────────────────────┤
│ Histórico chart (estático) │ LTTB downsample ≤ 2000 pts│
│                            │ Canvas renderer            │
│                            │ animation: true (500ms)    │
│                            │ React.memo + useMemo       │
├────────────────────────────┼────────────────────────────┤
│ Tabela de dados live       │ @tanstack/react-virtual    │
│                            │ max 500 rows visíveis      │
│                            │ prepend novos, drop antigos│
├────────────────────────────┼────────────────────────────┤
│ Alert log                  │ Circular buffer (max 100)  │
│                            │ Newest on top              │
│                            │ Virtual scroll se > 50     │
└────────────────────────────┴────────────────────────────┘
```

**Dogmas de Performance**:
- NUNCA usar `setState` para cada mensagem WebSocket — use refs + requestAnimationFrame.
- NUNCA renderizar > 2000 pontos num gráfico — use LTTB downsampling.
- NUNCA habilitar animação em streaming charts — gera jank acumulativo.
- SEMPRE usar `Canvas` renderer do ECharts para live data.
- SEMPRE debounce filtros (≥ 300ms) antes de re-query.

---

## 7. Estrutura de Projeto

```
backend/ (Rust — Axum)
├── src/
│   ├── monitoring/
│   │   ├── mod.rs
│   │   ├── routes.rs              # REST + WebSocket + SSE endpoints
│   │   ├── ingest.rs              # Ingest handler + batch persist
│   │   ├── ws_hub.rs              # WebSocket broadcast hub
│   │   ├── sse.rs                 # SSE status endpoint
│   │   ├── query.rs               # Tiered query (raw → 1m → 1h)
│   │   └── downsample.rs          # LTTB algorithm
│   ├── alerts/
│   │   ├── mod.rs
│   │   ├── rules.rs               # AlertRule CRUD
│   │   ├── evaluator.rs           # Avalia regras contra data points
│   │   ├── dispatcher.rs          # Multi-channel notification
│   │   └── absence_checker.rs     # Job que detecta ausência de dados
│   └── migrations/
│       ├── 001_metrics_hypertable.sql
│       ├── 002_continuous_aggregates.sql
│       └── 003_alert_rules.sql
│
frontend/ (React)
├── src/features/monitoring/
│   ├── components/
│   │   ├── StreamingChart.tsx      # ECharts + circular buffer + rAF
│   │   ├── MetricGrid.tsx          # Grid de métricas com cards
│   │   ├── ConnectionIndicator.tsx # Status WebSocket
│   │   ├── LiveIndicator.tsx       # Pulsing red dot
│   │   └── AlertPanel.tsx          # Lista de alertas ativos
│   ├── hooks/
│   │   ├── useRealtimeWebSocket.ts # WebSocket + auto-reconnect
│   │   ├── useRealtimeAlerts.ts    # Alertas via WS
│   │   └── useMetricHistory.ts     # TanStack Query para histórico
│   └── services/
│       ├── monitoring.service.ts   # API calls
│       └── alert.service.ts        # Alert CRUD + acknowledge
```

---

## 8. Checklist Senior+ — Real-Time Monitoring

- [ ] **WebSocket para live data** — broadcast por tenant, com heartbeat 30s.
- [ ] **Auto-reconnect** — exponential backoff até 30s, max 10 retries.
- [ ] **Circular buffer** — max 300 pontos no gráfico streaming.
- [ ] **requestAnimationFrame** — updates de gráfico via rAF, NUNCA setState direto.
- [ ] **animation: false** — em streaming charts para evitar jank.
- [ ] **Canvas renderer** — ECharts sempre com `renderer: 'canvas'` para live.
- [ ] **LTTB downsample** — max 2000 pontos para gráficos históricos.
- [ ] **TimescaleDB hypertable** — métricas em hypertable com chunk_time_interval 1 dia.
- [ ] **Continuous aggregates** — 1m e 1h pré-calculados, auto-refresh.
- [ ] **Tiered query** — <6h=raw, <7d=1m, >7d=1h automaticamente.
- [ ] **Compression** — chunks > 7 dias comprimidos automaticamente.
- [ ] **Retention** — raw=30d, 1m=90d, 1h=sem limite.
- [ ] **Bulk insert** — UNNEST para batch insert, NUNCA 1 INSERT por ponto.
- [ ] **Alert cooldown** — anti-spam com cooldown configurável por regra.
- [ ] **Consecutive points** — threshold exige N pontos consecutivos para alertar.
- [ ] **Multi-channel** — email, slack, webhook, SMS (critical only).
- [ ] **Connection indicator** — pulsing dot verde/amarelo/vermelho no dashboard.
- [ ] **Live indicator** — red pulsing dot em streaming charts.
- [ ] **Absence detection** — job periódico detecta sources que pararam de enviar.
- [ ] **Multi-tenant** — broadcast channels e queries isolados por tenant_id.
