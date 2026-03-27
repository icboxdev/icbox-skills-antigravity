---
name: IoT Edge & Fog Computing
description: Architect, validate, and optimize distributed computing architectures for IoT enforcing edge data processing, fog layer orchestration, cloud-edge partitioning, latency-aware workload placement, and offline-first resilience patterns. Concept-focused, stack-agnostic.
---

# IoT Edge & Fog Computing — Diretrizes Senior+

## 1. Princípio Fundamental

"Enviar tudo para a cloud" é o anti-pattern #1 em IoT. **Processar o máximo possível perto da fonte de dados** reduz latência, custo de transmissão e dependência de conectividade.

> ⚠️ Se seu sistema IoT para de funcionar quando perde internet, você falhou na arquitetura.

---

## 2. Definições Precisas

### Edge Computing
Processamento NO DEVICE ou em hardware imediatamente adjacente (gateway, micro-server). Latência < 10ms.

### Fog Computing
Camada intermediária ENTRE edge e cloud. Múltiplos fog nodes distribuídos geograficamente. Latência < 100ms.

### Cloud Computing
Processamento centralizado em datacenter. Latência 50ms-500ms+. Capacidade ilimitada.

```
┌─────────────────────────────────────────────────────┐
│                     CLOUD                           │
│  ML Training, Long-term Storage, Global Analytics   │
│  Latência: 50-500ms  │  Capacidade: ∞              │
├─────────────────────────────────────────────────────┤
│                      FOG                            │
│  Correlação multi-device, Regional aggregation      │
│  Latência: 10-100ms  │  Capacidade: Média           │
├─────────────────────────────────────────────────────┤
│                     EDGE                            │
│  Filtragem, Alertas locais, Amostragem              │
│  Latência: < 10ms    │  Capacidade: Limitada        │
├─────────────────────────────────────────────────────┤
│                   DEVICES                           │
│  Sensores, Atuadores, MCUs                          │
│  Latência: < 1ms     │  Capacidade: Mínima          │
└─────────────────────────────────────────────────────┘
```

---

## 3. Workload Placement — O Que Processar Onde

### 3.1 Matriz de Decisão

| Critério | Device/Edge | Fog | Cloud |
|---|---|---|---|
| **Latência crítica** (< 50ms) | ✅ | ⚠️ | ❌ |
| **Volume de dados alto** (reduzir) | ✅ filtrar | ✅ agregar | ❌ armazenar tudo |
| **Conectividade intermitente** | ✅ offline-first | ✅ buffer | ❌ depende |
| **ML Inference** (modelo pronto) | ✅ TinyML | ✅ | ✅ |
| **ML Training** (requer dataset) | ❌ | ❌ | ✅ |
| **Correlação cross-device** | ❌ | ✅ | ✅ |
| **Analytics histórico** | ❌ | ❌ | ✅ |
| **Controle de atuador** | ✅ local loop | ⚠️ backup | ❌ alta latência |

### 3.2 Regra de Ouro

```
CERTO: Data Reduction Pipeline
Device (1000 leituras/s) 
  → Edge: média móvel + filtro outlier (10 msgs/s)
    → Fog: agregação por minuto + anomaly detection (1 msg/min)
      → Cloud: storage, dashboard, ML training

ERRADO: Firehose para Cloud
Device (1000 leituras/s) → Cloud (1000 msgs/s × 10.000 devices = 10M msgs/s)
  → Custo proibitivo, latência alta, single point of failure
```

---

## 4. Padrões Arquiteturais Edge

### 4.1 Edge Gateway Pattern

```
┌─ Edge Gateway ──────────────────────────┐
│                                         │
│  ┌──────────┐  ┌──────────┐             │
│  │ Protocol │  │ Data     │             │
│  │ Adapter  │  │ Buffer   │── Offline   │
│  │ Modbus,  │  │ SQLite,  │   Queue     │
│  │ BLE, I²C │  │ LevelDB  │             │
│  └────┬─────┘  └────┬─────┘             │
│       │              │                   │
│  ┌────▼──────────────▼─────┐             │
│  │    Processing Engine     │             │
│  │  Filter → Aggregate →   │             │
│  │  Alert → Transform      │             │
│  └────────────┬────────────┘             │
│               │                          │
│  ┌────────────▼────────────┐             │
│  │  Upstream Sync Engine   │             │
│  │  MQTT / HTTP Batch      │             │
│  └─────────────────────────┘             │
└─────────────────────────────────────────┘
```

### 4.2 Offline-First Pattern

```
1. Device coleta dados continuamente
2. Armazena em buffer local (SQLite, LevelDB, arquivo)
3. Sync Engine tenta enviar periodicamente
4. Se falha → enfileira com retry exponencial
5. Se buffer cheio → FIFO (descarta mais antigos)
6. Quando reconecta → flush do buffer (batch upload)
7. NUNCA bloquear coleta por causa de sync failure
```

### 4.3 Local Control Loop (Safety-Critical)

```
┌── Sensor ──→ Edge Controller ──→ Actuator ─┐
│              (decisão local)                │
│              latência < 10ms                │
│              NÃO depende de cloud           │
└─────────────────────────────────────────────┘

Cloud recebe CÓPIA para logging/analytics,
mas NUNCA está no caminho crítico do controle.
```

---

## 5. Fog Computing — Camada Intermediária

### 5.1 Responsabilidades do Fog Node

1. **Agregação Regional**: Combinar dados de múltiplos edge gateways
2. **Correlação Cross-Device**: Detectar padrões multi-sensor
3. **Cache Regional**: Reduzir consultas ao cloud
4. **Model Inference**: Executar ML models para região
5. **Policy Enforcement**: Aplicar regras locais de compliance

### 5.2 Fog Node Placement

```
┌── Site A ───────┐   ┌── Site B ───────┐
│ GW1  GW2  GW3   │   │ GW4  GW5  GW6   │
│   └──┼──┘       │   │   └──┼──┘       │
│      │          │   │      │          │
│  ┌───▼───┐      │   │  ┌───▼───┐      │
│  │Fog    │      │   │  │Fog    │      │
│  │Node A │      │   │  │Node B │      │
│  └───┬───┘      │   │  └───┬───┘      │
└──────┼──────────┘   └──────┼──────────┘
       │                     │
       └─────────┬───────────┘
            ┌────▼────┐
            │  CLOUD  │
            └─────────┘
```

---

## 6. Edge AI / TinyML

### 6.1 Quando Usar ML no Edge

| Cenário | Edge ML? | Motivo |
|---|---|---|
| Detecção de anomalia real-time | ✅ | Latência intolerável via cloud |
| Classificação de imagem em câmera | ✅ | Banda insuficiente para stream |
| Keyword spotting (voice) | ✅ | Privacidade + latência |
| Treinamento de modelo | ❌ | Requer dataset completo + GPU |
| Previsão de séries temporais complexas | ⚠️ | Inference ok, training no cloud |

### 6.2 Regras de TinyML

- Modelo DEVE caber na RAM do MCU (tipicamente < 256KB)
- Usar quantização INT8 para reduzir modelo
- Inference time DEVE ser < período de amostragem
- NUNCA treinar no device — apenas inference de modelo pré-treinado

---

## 7. Dogmas

### NUNCA
- ❌ NUNCA fazer controle de atuador safety-critical via cloud
- ❌ NUNCA transmitir dados crus sem pré-processamento no edge
- ❌ NUNCA assumir 100% uptime de conectividade
- ❌ NUNCA colocar fog nodes sem redundância em ambiente crítico
- ❌ NUNCA ignorar custo de egress do cloud provider

### SEMPRE
- ✅ SEMPRE implementar store-and-forward no edge
- ✅ SEMPRE definir data retention policy no edge (evitar disk full)
- ✅ SEMPRE ter fallback local quando cloud está indisponível
- ✅ SEMPRE monitorar saúde do edge (CPU, RAM, disk, temp)
- ✅ SEMPRE versionar e atualizar edge software via OTA
