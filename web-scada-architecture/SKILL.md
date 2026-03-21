---
name: Web SCADA & Industrial Supervisory Architecture
description: Architect, generate, and validate Web SCADA and Industrial Supervisory systems. Enforces high-performance telemetry streaming (WebSocket/ECharts), strict IT/OT separation, TimescaleDB retention policies, and real-time control dogmas for Rust/React stacks.
---

# Web SCADA & Industrial Supervisory Architecture

Esta skill dita o dogmatismo estrutural para a criação de Sistemas Supervisórios (HMI/SCADA) baseados em tecnologias web modernas (Rust no Backend + React no Frontend). O objetivo é garantir que a aplicação web possua a mesma robustez, latência previsível e segurança de um SCADA tradicional on-premise.

## 1. Princípios Arquiteturais (Zero-Trust OT/IT)

1. **Separação de Tráfego (IT/OT)**: O Web SCADA (Nível 2/3 do Modelo Purdue) NUNCA deve consultar diretamente os equipamentos de chão de fábrica (Nível 0/1). Todo tráfego deve obrigatoriamente passar por um Broker IIoT (ex: MQTT) ou Gateway RPC seguro em Rust.
2. **Latência Previsível**: Atualizações de UI para telemetria bruta não devem engargalar a main thread. O uso excessivo do React State (`useState`) em loops sub-segundo congelará a aba. Utilize referências mutáveis (`useRef`) e renderização em Canvas (`ECharts`, `Chart.js` com decimation).
3. **Controle de Estado Desejado vs Reportado**: Comandos de operação (ex: "Ligar Bomba") devem apenas enviar a intenção (`desired_state`). A UI só deve ser renderizada como ativa quando o equipamento confirmar a alteração em tempo real (`reported_state`).

## 2. Padrões de Frontend (Alta Frequência)

A renderização de gráficos complexos com milhares de pontos históricos e streaming ao vivo é a principal causa de falhas em supervisórios web.

### Exemplo (Few-Shot): Streaming de Telemetria sem UI Blocking

```tsx
// ❌ ERRADO: Atualizar primitivos imutáveis no estado do React 60x por segundo
const [data, setData] = useState([]);
ws.onmessage = (msg) => {
  setData(prev => [...prev, msg.value]); // Dispara re-renders constantes, esgotando o Event Loop CPU 100%
};

// ✅ CERTO: Usar Circular Buffers locais e RequestAnimationFrame para flush da Engine Canvas (ECharts)
const dataBuffer = useRef([]);
const chartRef = useRef(null);

ws.onmessage = (msg) => {
  dataBuffer.current.push(msg.value); // Mutação leve de O(1) sem acionar render cycle
  // O buffer é flusheado periodicamente para a Engine
};

useEffect(() => {
  const timer = setInterval(() => {
    if (chartRef.current && dataBuffer.current.length > 0) {
      // Delega o batch render para a placa de vídeo (via Canvas APIs)
      chartRef.current.setOption({ series: [{ data: dataBuffer.current }] });
    }
  }, 100); // 10fps é o limite de cognição humana para séries temporais ao vivo
  return () => clearInterval(timer);
}, []);
```

## 3. Padrões de Backend (Time-Series e Aggregate Queries)

Dados industriais geram Terabytes rapidamente. Bancos relacionais puros não suportam scan contínuo dessas massas temporais para plotar gráficos longos.

1. **Uso de TimescaleDB Obligatório**: O Postgres deve operar com *Hypertables* particionadas ativamente por tempo.
2. **Consultas em Agregados Contínuos**: NUNCA selecione dados brutos (`telemetry_raw`) para preencher gráficos de janelas amplas (> 24 horas). Use `continuous aggregates` consolidados.

### Exemplo (Few-Shot): Query Dinâmica por Resolução

```rust
// ❌ ERRADO: Select raw que ignorando resolução. (Ex: Trazer 2 milhões de pontos para uma tela de 1080p width)
sqlx::query!("SELECT time, value FROM telemetry WHERE sensor_id = $1 AND time > $2", id, start);

// ✅ CERTO: Switch semântico selecionando a visualização pré-agregada ideal (LTTB - Largest Triangle Three Buckets)
let table_view = if duration > Duration::days(1) {
    "telemetry_1h_agg"
} else if duration > Duration::hours(2) {
    "telemetry_1m_agg"
} else {
    "telemetry_raw"
};

let query = format!("SELECT time_bucket as time, avg_value as value FROM {} WHERE sensor_id = $1 AND time_bucket >= $2", table_view);
let results = sqlx::query_as::<_, MetricPoint>(&query).bind(id).bind(start).fetch_all(db).await?;
```

## 4. Segurança de Comando em Equipamentos Críticos (Safety First)

Escrever variáveis num processo pode disparar ações reais devastadoras. Todo comando de escrita (Write Holding Register) originado do Supervisório DEVE seguir padrões rigorosos:

1. **Padrão SBO (Select Before Operate)**: Máquinas críticas não podem ligar em um único clique sem confirmação da central administrativa do backend. O operador seleciona, o backend libera as intertravas, só então é operado.
2. **Auditoria Rigorosa (Audit Trail)**: Cada instrução despachada pelo WebSocket origina um insert IMEDIATO na tabela `audit_logs` (registrando `user_id, ip_address, param_target, old_val, new_val`).
3. **Dead-Man Switch / Timeouts Críticos**: O protocolo deve embutir TTL. Retardos de rede (`lag`) podem fazer um comando de emergência perder o sentindo e atuar depois que o defeito já se alarmou. Valide tempo de despacho.

## 5. Regra Inviolável de Testabilidade (Zero-Dirt no Disco)

Qualquer script temporal demandado pelo desenvolvedor ou Agente para falsificar cenários caóticos — como injetar pulsos Modbus erráticos, gerar ruído sintético em MQTT ou mockar massas para o PostgreSQL — **DEVE** obedecer explicitamente as diretrizes corpotivas de `Temporary Scripts`.

- ⚠️ **MANDATÓRIO**: Tais geradores(`simulate_ot_noise.py`, `mqtt_flood.sh`) precisam ser alocados dentro de `/tmp/`.
- ❌ **PROIBIDO**: Sujar o diretório da Source Tree do SCADA Web com arquivos de automação para ensaios esporádicos.
- Terminando a bateria de validação empírica do backend ou frontend, todo o rastro sintético injetado a partir da pasta `/tmp/` no sistema host **deve ser dizimado**.
