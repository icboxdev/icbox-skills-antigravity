---
name: OpenTelemetry Observability (Tracing & Metrics)
description: Architect, generate, and validate Cloud Observability platforms utilizing OpenTelemetry. Enforces vendor-neutral distributed tracing, OpenTelemetry Collector topology, RED metrics derivation, and context propagation in microservices.
---

# OpenTelemetry Observability (Tracing & Metrics)

A monitoria baseada puramente em logs de texto morreu. Cargas de trabalho assíncronas, serverless e microsserviços exigem visibilidade estruturada capaz de cruzar dezenas de instâncias com exatidão cronológica.

## 🏛️ Dogmas de Arquitetura OpenTelemetry (OTel)

1. **OTEL COLLECTOR É OBRIGATÓRIO (Topology):** Nunca mande traces ou métricas dos seus apps diretamente para serviços em nuvem (Ex: SDK -> Grafana Cloud direto). OBRIGATÓRIO implementar a arquitetura usando o `OpenTelemetry Collector` como sidecar ou gateway. Ele atua como centralizador de recebimento (Receiver), filtro em lote (Processor) e envio multi-plataforma (Exporter). Isso blinda os apps contra instabilidades de conexão e vendors lock-in.
2. **PROPAGAÇÃO DE CONTEXTO ABSOLUTA:** Em arquiteturas distribuídas, a requisição A (Frontend) chama B (Backend) que chama C (Banco). OBRIGATÓRIO garantir a injeção do cabeçalho oficial da W3C `traceparent` no momento do HTTP Outbound Request e sua extração no Inbound, unificando a história em um "Trace ID" único.
3. **MÉTRICAS "RED" SÃO A META PRINCIPAL:** O padrão ouro de SRE para painéis de saúde em APIs baseia-se em *Rate* (Taxa de requisições por seg), *Errors* (Taxa percentual de falhas) e *Duration* (Latência do percentil P95/P99). OBRIGATÓRIO utilizar o OpenTelemetry Collector com o processor `spanmetrics` para derivar automaticamente métricas RED a partir dos Traces, consolidando o output no Grafana Prometheus.
4. **CORRELAÇÃO TRACE-LOG:** Logs soltos num mar de Gigabytes são inúteis. Todos os sistemas de Log estruturado (Winston, Tracing do Rust) OBRIGATORIAMENTE DEVEM inibir a string de log adicionando em cada JSON impresso o "trace_id" e o "span_id" correntes injetados pelo SDK do OpenTelemetry, garantindo que o Grafana seja capaz de fazer o "Pivot" (Clique num Trace -> Veja o log exato daquele momento).
5. **EARLY INITIALIZATION:** OpenTelemetry Instrumentation Labs não trabalham de forma mágica se invocados tardiamente. OBRIGATÓRIO invocar o script de Bootstrap do Tracer no momento Zero de execução do App, antes de importar os frameworks principais (Express, Axum, Prisma).

## 🛑 Padrões (Certo vs Errado)

### Arquitetura Collector e Métricas RED (Spanmetrics)

**❌ ERRADO** (Instrumentação Vendor-Lock sem collector pipeline):
```typescript
// App TypeScript envia direto atrelado comercialmente ao vendor
import tracer from 'dd-trace';
tracer.init({ logInjection: true, env: 'prod', hostname: 'api.datadoghq.com' })
```

**✅ CERTO** (Exportação pura OTLP Local para o OTel Collector):
```typescript
// Node.js envia via formato padrão gRPC local. O Collector cuidará de processar massivamente e enviar.
const exporter = new OTLPTraceExporter({ url: "http://localhost:4318/v1/traces" });
provider.addSpanProcessor(new BatchSpanProcessor(exporter));
// Todo Vendor agora pode ser trocado mudando apenas o YAML do collector.
```

**YAML Config Padrão do Collector (Gerando RED Metrics no ar):**
```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols: { grpc: {}, http: {} }

processors:
  batch: {}
  spanmetrics:
    # A magia do RED: Coleta as durações das traces e transforma em Metric Data no formato Prometheus
    metrics_exporter: prometheus
    latency_histogram_buckets: [2ms, 6ms, 10ms, 100ms, 250ms, 500ms, 1s, 10s]

exporters:
  otlp/tempo: # Envia Traces pro Grafana Tempo
    endpoint: tempo:4317
    tls: { insecure: true }
  prometheus: # Expõe as Métricas agregadas pra captura no Dashboard
    endpoint: "0.0.0.0:8889"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [spanmetrics, batch]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp]
      exporters: [prometheus]
```

### Context Propagation (Axios / Fetch)

Quando um Service A liga pro Service B no Backend Server-to-Server.

**❌ ERRADO** (Service A perde o contexto Trace original):
```typescript
// Uma API chamada no meio da requisição não leva NADA para API B. 
// Para o Grafana, essa é uma requisição órfã que não existe no Grafo de Dependências.
const response = await fetch("http://service-b/api/users"); 
```

**✅ CERTO** (Injeção de W3C Propagator Automática):
Na maioria dos instrumentadores (Ex: `@opentelemetry/instrumentation-http`), isso é feito nos bastidores por monkey patching. Caso manual:
```typescript
import { propagation, context } from '@opentelemetry/api';

const headers = {};
// Extrai o W3C Trace do Context Atual do OTel e "Injeta" nos cabeçalhos vazios
propagation.inject(context.active(), headers); 
// Headers agora contém: { "traceparent": "00-4bf92f3577b3...-01" }

const response = await fetch("http://service-b/api/users", { headers });
```

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

