---
name: IoT Communication Protocols
description: Evaluate, select, and architect IoT communication stacks comparing MQTT, CoAP, AMQP, HTTP, WebSocket, LoRaWAN, Zigbee, BLE, NB-IoT, LTE-M, Thread, and Matter. Enforces protocol selection matrices, QoS trade-offs, and power/range/bandwidth analysis. Concept-focused, stack-agnostic.
---

# IoT Communication Protocols — Diretrizes Senior+

## 1. Princípio Fundamental

Não existe protocolo IoT "melhor". Existe o **protocolo correto para o contexto**. A seleção DEVE ser baseada em 5 eixos: **Energia, Alcance, Throughput, Latência e Confiabilidade**.

> ⚠️ Escolher MQTT "porque todo mundo usa" sem avaliar requisitos é engenharia preguiçosa. SEMPRE justifique a escolha com a matriz de decisão.

---

## 2. Taxonomia de Protocolos

### 2.1 Por Camada

```
┌─────────────────────────────────────────────────┐
│  APPLICATION    │ MQTT, CoAP, AMQP, HTTP, WS    │
├─────────────────┼───────────────────────────────-┤
│  TRANSPORT      │ TCP, UDP, DTLS, TLS            │
├─────────────────┼───────────────────────────────-┤
│  NETWORK        │ IPv4, IPv6, 6LoWPAN, Thread     │
├─────────────────┼───────────────────────────────-┤
│  DATA LINK/PHY  │ WiFi, BLE, Zigbee, LoRa, NB-IoT│
└─────────────────┴───────────────────────────────-┘
```

### 2.2 Por Alcance

| Categoria | Alcance | Protocolos |
|---|---|---|
| **PAN** (Personal) | < 10m | BLE, NFC, RFID |
| **LAN** (Local) | 10-100m | WiFi, Zigbee, Thread, Z-Wave |
| **NAN** (Neighborhood) | 100m-1km | Zigbee Mesh, WiFi HaLow |
| **WAN** (Wide) | 1-15km | LoRaWAN, Sigfox, NB-IoT, LTE-M |
| **Global** | Ilimitado | 4G/5G, Satellite IoT |

---

## 3. Protocolos de Aplicação — Deep Dive

### 3.1 MQTT (Message Queuing Telemetry Transport)

```
Modelo:       Publish/Subscribe (via Broker)
Transporte:   TCP (porta 1883) / TLS (porta 8883)
Overhead:     2 bytes header mínimo
QoS Levels:   0 (at most once), 1 (at least once), 2 (exactly once)
```

**Quando Usar:**
- Redes instáveis, alta latência, baixa largura de banda
- Telemetria contínua sensor → cloud
- Fan-out de mensagens para múltiplos subscribers
- Quando precisa de Last Will Testament (detecção de desconexão)

**Quando NÃO Usar:**
- Request/Response simples (use CoAP/HTTP)
- Devices ultra-constrained sem TCP stack
- Quando precisa de multicast nativo (CoAP faz melhor)

**QoS Selection:**

| QoS | Garantia | Overhead | Usar Quando |
|---|---|---|---|
| 0 | Fire-and-forget | Mínimo | Telemetria frequente onde perder 1 msg é ok |
| 1 | At-least-once | Médio | Alertas, eventos que não podem se perder |
| 2 | Exactly-once | Alto | Comandos críticos, billing, transações |

### 3.2 CoAP (Constrained Application Protocol)

```
Modelo:       Request/Response (como HTTP)
Transporte:   UDP (porta 5683) / DTLS (porta 5684)
Overhead:     4 bytes header fixo
Features:     Resource Discovery, Observe (push), Multicast
```

**Quando Usar:**
- Devices ultra-constrained (< 256KB RAM, < 100MHz CPU)
- Comunicação 1:1 device ↔ server
- Quando precisa de discover de recursos
- Smart home, sensores de baixíssimo consumo

**Quando NÃO Usar:**
- Fan-out para múltiplos subscribers (use MQTT)
- Streams contínuos de alta frequência
- Quando precisa de garantia de entrega forte (TCP melhor)

### 3.3 AMQP (Advanced Message Queuing Protocol)

```
Modelo:       Producer → Exchange → Queue → Consumer
Transporte:   TCP (porta 5672) / TLS (porta 5671)
Features:     Routing, Persistence, Acknowledgments, Transactions
```

**Quando Usar:**
- Enterprise messaging com garantia de entrega
- Routing complexo (topic, fanout, headers, direct)
- Backend-to-backend (cloud processing pipelines)
- Financial/billing systems que não toleram perda

**Quando NÃO Usar:**
- Devices constrained (overhead alto)
- Comunicação device ↔ cloud direta (use MQTT)
- Simplicidade é prioridade

### 3.4 HTTP/REST

```
Modelo:       Request/Response (síncrono)
Transporte:   TCP/TLS (portas 80/443)
Overhead:     Alto (headers texto)
```

**Quando Usar:**
- Integração com APIs existentes
- Devices com poder de processamento (RPi, gateways)
- Firmware download / OTA updates
- Quando já existe infraestrutura HTTP

**Quando NÃO Usar:**
- Telemetria de alta frequência (overhead proibitivo)
- Devices a bateria (TCP handshake caro)
- Push notifications (polling é desperdício)

### 3.5 WebSocket

```
Modelo:       Full-duplex bidirecional persistente
Transporte:   TCP/TLS (upgrade de HTTP)
```

**Quando Usar:**
- Real-time bidirecional (chat, controle remoto)
- Dashboards live com streaming de dados
- Gateway ↔ Cloud control plane
- Quando precisa de push server → client

---

## 4. Protocolos de Rede Física — Deep Dive

### 4.1 Matriz Comparativa

| Protocolo | Alcance | Data Rate | Energia | Topologia | Frequência | Custo/Device |
|---|---|---|---|---|---|---|
| **WiFi** | 50-100m | 1-1000 Mbps | Alto | Star | 2.4/5/6 GHz | Médio |
| **BLE 5.x** | 10-100m | 2 Mbps | Ultra-baixo | Star/Mesh | 2.4 GHz | Baixo |
| **Zigbee** | 10-100m | 250 kbps | Baixo | Mesh/Star/Tree | 2.4 GHz | Baixo |
| **Thread** | 10-100m | 250 kbps | Baixo | Mesh (IP) | 2.4 GHz | Baixo |
| **Z-Wave** | 30-100m | 100 kbps | Baixo | Mesh | 800-900 MHz | Médio |
| **LoRaWAN** | 2-15 km | 0.3-50 kbps | Ultra-baixo | Star-of-Stars | Sub-GHz | Baixo |
| **NB-IoT** | 10-15 km | 250 kbps | Baixo | Star (celular) | Licensed | Médio |
| **LTE-M** | 10-15 km | 1 Mbps | Médio | Star (celular) | Licensed | Alto |
| **Sigfox** | 10-50 km | 100 bps | Ultra-baixo | Star | Sub-GHz | Baixo |

### 4.2 Árvore de Decisão

```
Precisa de alta taxa de dados (> 1 Mbps)?
├── SIM → WiFi ou LTE-M/5G
└── NÃO
    ├── Alcance > 1 km?
    │   ├── SIM
    │   │   ├── Precisa de bidirecional frequente? → NB-IoT ou LTE-M
    │   │   └── Transmissão infrequente (< 12 msgs/dia)? → LoRaWAN ou Sigfox
    │   └── NÃO (< 1 km)
    │       ├── Precisa de mesh networking? → Zigbee, Thread ou BLE Mesh
    │       ├── Wearable / ultra-curta distância? → BLE
    │       └── Smart Home com IP nativo? → Thread / Matter
    └── Alimentação por bateria (anos)?
        ├── SIM → LoRaWAN, BLE, Zigbee (baixo duty cycle)
        └── NÃO → WiFi, Ethernet (alimentação contínua)
```

---

## 5. Matter & Thread — O Futuro do Smart Home

**Matter** (ex-CHIP): Standard unificado de smart home (Apple, Google, Amazon, Samsung).
- Roda sobre **Thread** (mesh IPv6), **WiFi**, e **Ethernet**
- Interoperabilidade cross-vendor
- Comissionamento local (sem cloud obrigatório)

**Thread**: Protocolo mesh IPv6 de baixo consumo baseado em IEEE 802.15.4.
- Border Router traduz Thread ↔ WiFi/Ethernet
- Auto-healing mesh (sem single point of failure)
- Ideal para automação residencial e predial

---

## 6. Dogmas de Seleção

### NUNCA
- ❌ NUNCA usar WiFi para devices a bateria que precisam durar meses
- ❌ NUNCA usar HTTP polling para telemetria de alta frequência
- ❌ NUNCA usar MQTT QoS 2 para telemetria onde QoS 0 ou 1 basta
- ❌ NUNCA ignorar o custo de dados em redes celulares (NB-IoT/LTE-M)
- ❌ NUNCA usar protocolo sem criptografia de transporte em produção
- ❌ NUNCA assumir que "funciona no lab" = funciona em campo (range, interferência)
- ❌ NUNCA misturar frequências licensed e unlicensed sem análise regulatória

### SEMPRE
- ✅ SEMPRE avaliar consumo energético por mensagem transmitida
- ✅ SEMPRE considerar o pior caso de conectividade (95th percentile)
- ✅ SEMPRE usar TLS/DTLS para protocolos de aplicação em produção
- ✅ SEMPRE dimensionar o broker/gateway para pico de conexões simultâneas
- ✅ SEMPRE testar em ambiente real (interferência, obstáculos, distância)
- ✅ SEMPRE ter fallback de protocolo para cenários de degradação

---

## 7. Pattern: Protocol Translation Gateway

```
┌──────────┐    ┌──────────────┐    ┌──────────┐
│ Modbus   │    │              │    │          │
│ Device   │───→│   GATEWAY    │───→│  MQTT    │
│          │    │              │    │  Broker  │
├──────────┤    │ ┌──────────┐ │    │          │
│ Zigbee   │───→│ │ Protocol │ │    └──────────┘
│ Sensor   │    │ │ Adapter  │ │
├──────────┤    │ └──────────┘ │
│ BLE      │───→│              │
│ Beacon   │    └──────────────┘
```

O gateway DEVE:
1. Traduzir protocolos heterogêneos → protocolo unificado (MQTT)
2. Bufferizar dados durante desconexão
3. Agregar/filtrar antes de transmitir
4. Manter tabela de mapeamento device ↔ topic
