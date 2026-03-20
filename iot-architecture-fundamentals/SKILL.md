---
name: IoT Architecture & Reference Models
description: Architect, validate, and design IoT solutions enforcing layered reference models (3-layer, 5-layer, IoT-A), topology selection (Star, Mesh, Hybrid), gateway patterns, cloud-edge partitioning, and scalable system decomposition. Concept-focused, stack-agnostic.
---

# IoT Architecture & Reference Models — Diretrizes Senior+

## 1. Princípio Fundamental

IoT não é "conectar coisas". É **arquitetura de sistemas distribuídos** com restrições extremas de energia, conectividade, segurança e escala. Cada decisão arquitetural deve ser justificada por trade-offs mensuráveis.

> ⚠️ Projetar IoT sem modelo de referência é como construir prédio sem planta. NUNCA comece sem definir camadas e responsabilidades.

---

## 2. Modelos de Referência

### 2.1 Modelo 3 Camadas (Fundamental)

```
┌─────────────────────────────────────────┐
│         APPLICATION LAYER               │
│  Dashboards, Analytics, Rules Engine    │
├─────────────────────────────────────────┤
│          NETWORK LAYER                  │
│  Gateways, Brokers, Routing, Protocols  │
├─────────────────────────────────────────┤
│        PERCEPTION LAYER                 │
│  Sensors, Actuators, RFID, GPS, Câmeras │
└─────────────────────────────────────────┘
```

- **Perception**: Coleta dados crus do mundo físico. Hardware puro.
- **Network**: Transporta dados entre perception e application. Inclui gateways.
- **Application**: Transforma dados em ações: dashboards, alertas, automações.

### 2.2 Modelo 5 Camadas (Enterprise)

```
┌──────────────────────────────────────┐
│       BUSINESS LAYER                 │  ← Decisões de negócio, KPIs
├──────────────────────────────────────┤
│       APPLICATION LAYER              │  ← UI, APIs, integração
├──────────────────────────────────────┤
│       PROCESSING LAYER (Middleware)  │  ← Stream processing, ML, rules
├──────────────────────────────────────┤
│       TRANSPORT LAYER                │  ← MQTT, CoAP, HTTP, LoRaWAN
├──────────────────────────────────────┤
│       PERCEPTION LAYER               │  ← Sensores, atuadores, hardware
└──────────────────────────────────────┘
```

O modelo 5 camadas separa **transporte** de **processamento**, fundamental para arquiteturas de alta escala onde edge computing e stream processing operam independentemente.

### 2.3 IoT-A (Internet of Things Architecture)

Modelo de referência acadêmico/ISO que adiciona:
- **Virtual Entity Layer**: Device Twin / Digital Shadow
- **IoT Service Layer**: Abstração de recursos como serviços
- **Communication Layer**: Protocolos com QoS garantido

---

## 3. Topologias de Rede

### 3.1 Matriz de Decisão

| Topologia | Range | Escalabilidade | Resiliência | Energia | Quando Usar |
|---|---|---|---|---|---|
| **Star** | Médio | Baixa | Baixa (SPoF: hub) | Baixa | Smart Home, sensores simples |
| **Mesh** | Alto (hop) | Alta | Alta (auto-healing) | Alta | Industrial, smart cities |
| **Star-of-Stars** | Alto | Alta | Média | Média | LoRaWAN, campus corporativo |
| **Tree** | Médio | Média | Média | Média | Zigbee, automação predial |
| **Point-to-Point** | Curto | Nenhuma | Nenhuma | Mínima | BLE wearables, NFC |

### 3.2 Regras de Seleção

- **< 50 devices, área pequena**: Star com gateway central
- **50-500 devices, área média**: Star-of-Stars com gateways intermediários
- **500+ devices, área ampla**: Mesh com auto-healing (Zigbee, Thread)
- **Devices geograficamente distribuídos**: LoRaWAN Star-of-Stars
- **Ultra-baixo consumo, curta distância**: BLE Point-to-Point

---

## 4. Padrões Arquiteturais

### 4.1 Gateway Pattern

```
Sensors ──┐
Sensors ──┤── Gateway ── Cloud/Platform
Sensors ──┘     │
                ├── Protocol Translation (Modbus → MQTT)
                ├── Local Buffering (offline resilience)
                ├── Data Aggregation (reduce bandwidth)
                └── Edge Processing (pre-filtering)
```

**Regra**: Todo deployment IoT com mais de 5 devices DEVE ter um gateway intermediário. NUNCA conectar sensores diretamente à cloud em produção.

### 4.2 Cloud-Edge Partitioning

```
CERTO: Processamento distribuído
┌──────────┐    ┌──────────┐    ┌──────────┐
│  DEVICE  │ →  │   EDGE   │ →  │  CLOUD   │
│ raw data │    │ filter,  │    │ analytics│
│ sampling │    │ aggregate│    │ ML train │
│          │    │ alert    │    │ long-term│
└──────────┘    └──────────┘    └──────────┘

ERRADO: Tudo na cloud
┌──────────┐                    ┌──────────┐
│  DEVICE  │ ──────────────→    │  CLOUD   │
│ raw data │  enviar TUDO       │ processar│
│          │  alta latência     │ TUDO     │
└──────────┘  alto custo        └──────────┘
```

### 4.3 Regra do que Processar Onde

| Onde | O Que Processar | Latência | Exemplo |
|---|---|---|---|
| **Device** | Amostragem, calibração | < 1ms | Ler temperatura a cada 5s |
| **Edge/Gateway** | Filtro, agregação, alertas | < 100ms | Média de 10 leituras, alarme se > 80°C |
| **Fog** | Correlação multi-sensor | < 1s | Combinar temp + pressão para anomalia |
| **Cloud** | ML training, analytics | Minutos | Treinar modelo preditivo com histórico |

---

## 5. Decomposição de Sistema IoT

### 5.1 Componentes Obrigatórios

Todo sistema IoT DEVE ter, no mínimo:

1. **Device Registry**: Cadastro único por device (MAC, serial, cert)
2. **Provisioning Service**: Onboarding seguro de novos devices
3. **Data Ingestion**: Pipeline de ingestão de telemetria (MQTT/HTTP)
4. **Command/Control**: Canal de comandos device ← cloud (bidirecional)
5. **Device Shadow/Twin**: Estado virtual do device no cloud
6. **Rule Engine**: Processamento de regras e alertas
7. **Storage**: Time-series para telemetria + relacional para metadata
8. **API Gateway**: Exposição de dados para frontends e integrações

### 5.2 Componentes Avançados

- **OTA Manager**: Atualização remota de firmware
- **Analytics Engine**: Processamento batch e real-time
- **Digital Twin**: Simulação virtual do device/processo
- **Edge Orchestrator**: Gerenciamento de deployments edge

---

## 6. Dogmas Arquiteturais

### NUNCA
- ❌ NUNCA confiar na conectividade — todo device DEVE ter offline buffer
- ❌ NUNCA enviar dados crus sem filtro/agregação ao cloud
- ❌ NUNCA usar polling quando pub/sub resolve (desperdício de energia)
- ❌ NUNCA hardcodar IPs/URLs de servidores nos devices
- ❌ NUNCA projetar sem definir SLA de latência por camada
- ❌ NUNCA ignorar o custo de transmissão por byte em redes celulares/LoRa

### SEMPRE
- ✅ SEMPRE definir Device Identity única (MAC, certificado, UUID)
- ✅ SEMPRE implementar heartbeat/keepalive para monitorar conectividade
- ✅ SEMPRE usar timestamps UTC com precisão de milissegundos
- ✅ SEMPRE versionar o schema de telemetria (breaking changes matam frotas)
- ✅ SEMPRE planejar para falha parcial — devices vão desconectar
- ✅ SEMPRE separar data plane (telemetria) de control plane (comandos)

---

## 7. Métricas de Saúde do Sistema

| Métrica | Target | Alerta |
|---|---|---|
| **Device Online Rate** | > 95% | < 90% |
| **Ingestion Latency (p99)** | < 500ms | > 2s |
| **Message Loss Rate** | < 0.1% | > 1% |
| **Command ACK Rate** | > 99% | < 95% |
| **OTA Success Rate** | > 98% | < 90% |
| **Storage Write Throughput** | sustentado | degradando |

---

## 8. Escalabilidade — Thresholds

| Escala | Devices | Estratégia |
|---|---|---|
| **Small** | < 100 | Monolito, single DB, gateway único |
| **Medium** | 100-10K | Microservices, partitioned DB, multi-gateway |
| **Large** | 10K-1M | Event streaming (Kafka), sharded storage, regional gateways |
| **Massive** | 1M+ | Multi-region, edge mesh, federated control plane |
