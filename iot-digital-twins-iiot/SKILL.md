---
name: Industrial IoT (IIoT) & Digital Twins
description: Architect, validate, and design Industrial IoT solutions covering Purdue Model (ISA-95) levels, IT/OT convergence, OPC-UA interoperability, SCADA/PLC integration, Modbus communication, Digital Twin architecture, predictive maintenance, and Industry 4.0 patterns. Concept-focused, stack-agnostic.
---

# Industrial IoT (IIoT) & Digital Twins — Diretrizes Senior+

## 1. Princípio Fundamental

Industrial IoT não é IoT consumer com mais devices. É a convergência de **OT (Operational Technology)** com **IT (Information Technology)** em ambientes onde falhas causam **perda financeira, dano ambiental, ou risco a vidas humanas**.

> ⚠️ Em IIoT, disponibilidade e segurança industrial (safety) são mais importantes que features. NUNCA priorizar funcionalidade sobre confiabilidade.

---

## 2. Purdue Model (ISA-95) — Hierarquia Industrial

```
┌────────────────────────────────────────────────┐
│  LEVEL 5: Enterprise Network (DMZ/Cloud)       │
│  ERP, SCM, CRM, Analytics, Data Lake           │
├────────────────────────────────────────────────┤
│  LEVEL 4: Business Planning & Logistics        │
│  ERP local, Scheduling, Supply Chain           │
├────────────────────────────────────────────────┤
│  LEVEL 3: Manufacturing Operations (MES/MOM)   │  ← IT/OT Boundary
│  Workflow, Quality, Maintenance, Historian      │
├────────────────────────────────────────────────┤
│  LEVEL 2: Supervisory Control (SCADA/HMI)      │
│  SCADA, HMI, Engineering Workstations          │
├────────────────────────────────────────────────┤
│  LEVEL 1: Basic Control (PLC/DCS)              │
│  PLCs, DCS, RTUs, Safety Systems (SIS)         │
├────────────────────────────────────────────────┤
│  LEVEL 0: Physical Process                     │
│  Sensors, Actuators, Motors, Valves, Robots     │
└────────────────────────────────────────────────┘
```

### 2.1 Regras de Interação Entre Níveis

- **Comunicação VERTICAL**: Level 0 → Level 5 (telemetria sobe)
- **Comandos DESCEM**: Level 3 → Level 1 → Level 0 (controle desce)
- **NUNCA pular níveis**: Level 0 NÃO fala direto com Level 5
- **DMZ obrigatória**: Entre Level 3 (OT) e Level 4 (IT) DEVE haver firewall/DMZ
- **Protocolos diferentes por nível**: Level 0-2 (Modbus, Profinet) ≠ Level 3-5 (HTTP, MQTT, OPC-UA)

---

## 3. Protocolos Industriais

### 3.1 Matriz Comparativa

| Protocolo | Nível Purdue | Modelo | Transporte | Quando Usar |
|---|---|---|---|---|
| **Modbus RTU** | 0-1 | Master/Slave | Serial (RS-485) | Equipamentos legados, sensores simples |
| **Modbus TCP** | 0-2 | Master/Slave | TCP/IP | Retrofit de Modbus RTU para Ethernet |
| **OPC-UA** | 0-5 | Client/Server + Pub/Sub | TCP, MQTT | Integração vertical moderna (Industry 4.0) |
| **Profinet** | 0-2 | Provider/Consumer | Ethernet Real-Time | Automação Siemens, alta velocidade |
| **EtherNet/IP** | 0-2 | Producer/Consumer | TCP/UDP | Automação Allen-Bradley/Rockwell |
| **MQTT Sparkplug B** | 1-4 | Pub/Sub | TCP/TLS | IIoT data pipeline padronizado |
| **BACnet** | 0-2 | Client/Server | IP/MSTP | Automação predial (HVAC, iluminação) |

### 3.2 Modbus — Fundamentos Essenciais

```
Modelo de Dados Modbus:
┌──────────────────────────────────┐
│  Coils (1-bit R/W)               │  ← Saídas digitais
│  Discrete Inputs (1-bit RO)      │  ← Entradas digitais
│  Holding Registers (16-bit R/W)  │  ← Setpoints, configuração
│  Input Registers (16-bit RO)     │  ← Leituras de sensores
└──────────────────────────────────┘

Function Codes mais usados:
01: Read Coils
02: Read Discrete Inputs
03: Read Holding Registers  ← Mais comum para leitura
04: Read Input Registers
05: Write Single Coil
06: Write Single Register
16: Write Multiple Registers

Endianness:
⚠️ CUIDADO: Modbus é Big-Endian por padrão, mas valores float 32-bit
podem usar Word Swap. SEMPRE verificar documentação do device!
```

### 3.3 OPC-UA — Standard de Integração

```
OPC-UA resolve o problema:
  "Como um device Level 0 fala com um ERP Level 4?"

Características:
- Platform-independent (Windows, Linux, embedded)
- Security built-in (certificados X.509, criptografia)
- Information Model (self-describing data)
- Discovery (browse de variáveis em runtime)
- Pub/Sub mode (OPC-UA over MQTT para IIoT)

Quando usar OPC-UA:
✅ Integração multi-vendor
✅ Vertical integration (shop floor → cloud)
✅ Brownfield (conectar equipamentos existentes)
✅ Quando regulamentação exige standard aberto
```

---

## 4. SCADA — Controle Supervisório

### 4.1 Componentes de um Sistema SCADA

```
┌── SCADA Architecture ─────────────────────┐
│                                           │
│  ┌──────────┐    ┌──────────┐             │
│  │   HMI    │    │ Historian│             │
│  │ (telas)  │    │ (trend)  │             │
│  └────┬─────┘    └────┬─────┘             │
│       │               │                   │
│  ┌────▼───────────────▼─────┐             │
│  │    SCADA Server           │             │
│  │    - Polling PLCs         │             │
│  │    - Alarming             │             │
│  │    - Data logging         │             │
│  └────────────┬─────────────┘             │
│               │                           │
│  ┌────────────▼──────────────┐            │
│  │   Communication Network   │            │
│  │   Modbus, Profinet, OPC   │            │
│  └────────────┬─────────────┘             │
│               │                           │
│  ┌────┬───────┼───────┬────┐              │
│  │PLC │  │PLC │  │RTU │  │DCS│            │
│  └─┬──┘  └─┬──┘  └─┬──┘  └─┬─┘           │
│    │        │        │        │             │
│  ┌─▼──┐  ┌─▼──┐  ┌─▼──┐  ┌─▼──┐          │
│  │Sens│  │Actu│  │Sens│  │Motrs│          │
│  └────┘  └────┘  └────┘  └─────┘          │
└───────────────────────────────────────────┘
```

### 4.2 SCADA Modernization (IIoT)

Tendência 2024+: SCADA tradicional (on-premise) → **Cloud SCADA** + Edge

```
Legacy:  PLC → SCADA Server (local) → HMI (local)
Modern:  PLC → Edge Gateway (OPC-UA/MQTT) → Cloud SCADA → Web Dashboard
```

---

## 5. Digital Twin — Conceitos

### 5.1 Definição Precisa

Digital Twin é um **modelo virtual continuamente sincronizado** com um ativo físico, que inclui:
- **Dados em tempo real** (telemetria do device)
- **Modelo comportamental** (simulação física/ML)
- **Estado histórico** (timeline de mudanças)
- **Interação bidirecional** (simulação → ação no físico)

```
NÃO é Digital Twin:
- Dashboard com dados em tempo real (é visualização)
- Device Shadow/Twin básico (é sync de estado)
- Modelo 3D estático (é visualização)

É Digital Twin:
- Modelo que SIMULA comportamento futuro baseado em dados reais
- Modelo que recebe dados IoT E retorna predições/ações
- Réplica virtual que permite "what-if" scenarios
```

### 5.2 Níveis de Maturidade

```
Level 1: Digital Shadow (Read-only)
├── Dados fluem do físico → digital
├── Sem feedback do digital → físico
└── Exemplo: Dashboard time-series

Level 2: Digital Twin (Bidirecional)
├── Dados fluem nos dois sentidos
├── Config changes no digital → aplicam no físico
└── Exemplo: Device Twin com desired/reported state

Level 3: Predictive Twin (AI-Driven)
├── ML models preveem comportamento futuro
├── Alertas antes da falha (predictive maintenance)
└── Exemplo: Modelo de degradação de rolamento

Level 4: Autonomous Twin (Self-Optimizing)
├── Twin toma decisões sem intervenção humana
├── Otimiza parâmetros automaticamente
└── Exemplo: Auto-tuning de processo industrial
```

### 5.3 Arquitetura de Digital Twin

```
┌── Physical Asset ───────┐
│ Sensores, Atuadores      │
│ Modbus, OPC-UA, MQTT     │
└──────────┬───────────────┘
           │ Real-time data
           ▼
┌── Edge Processing ──────┐
│ Data filtering, buffering│
│ Local inference          │
└──────────┬───────────────┘
           │
           ▼
┌── Digital Twin Platform ────────────────┐
│                                         │
│  ┌───────────┐  ┌───────────┐           │
│  │ Data Lake │  │ Twin Model│           │
│  │ Raw +     │  │ Physics + │           │
│  │ Historical│  │ ML Model  │           │
│  └─────┬─────┘  └─────┬─────┘          │
│        │              │                 │
│  ┌─────▼──────────────▼──────┐          │
│  │  Simulation Engine         │          │
│  │  - What-if scenarios       │          │
│  │  - Failure prediction      │          │
│  │  - Optimization            │          │
│  └─────────────┬─────────────┘          │
│                │                        │
│  ┌─────────────▼─────────────┐          │
│  │  Visualization / API       │          │
│  │  3D render, dashboards     │          │
│  └───────────────────────────┘          │
└─────────────────────────────────────────┘
```

---

## 6. Predictive Maintenance

### 6.1 Evolução da Manutenção

```
Reactive:    Quebrou → conserta
             Custo mais alto, downtime máximo

Preventive:  Agenda fixa (a cada 3 meses)
             Custo médio, troca peças boas desnecessariamente

Predictive:  Dados indicam degradação → intervém ANTES da falha
             Custo otimizado, downtime mínimo

Prescriptive: AI recomenda AÇÃO específica + agenda automaticamente
              Custo mínimo, zero downtime planejável
```

### 6.2 Pipeline de Predictive Maintenance

```
1. Coleta de dados (vibração, temperatura, corrente, ruído)
2. Feature engineering (FFT, RMS, curtose, tendência)
3. Training: Modelo ML com dados históricos (normal + falha)
4. Deployment: Modelo no edge ou cloud
5. Inference: Scoring contínuo dos dados em tempo real
6. Alerta: Quando score > threshold → notificar equipe
7. Ação: Criar ordem de serviço automática no CMMS
```

### 6.3 Métricas de Saúde de Equipamento

| Indicador | Tipo | Sensor Típico |
|---|---|---|
| **Vibração** | RMS, FFT, envelope | Acelerômetro triaxial |
| **Temperatura** | Absoluta, delta, tendência | Termopar, IR |
| **Corrente elétrica** | RMS, harmônicas, desbalance | CT (Current Transformer) |
| **Pressão** | Absoluta, diferencial | Transdutor de pressão |
| **Ruído acústico** | dB, FFT, ultrassônico | Microfone industrial |
| **Oil analysis** | Partículas, viscosidade | Lab / online sensor |

---

## 7. IT/OT Convergence — Padrões

### 7.1 DMZ Architecture

```
┌── IT Network ────┐    ┌── DMZ ──────────┐    ┌── OT Network ───┐
│ ERP, Cloud, Apps │    │ Data Diode      │    │ SCADA, PLCs     │
│ Level 4-5        │◄───│ OPC-UA Gateway  │◄───│ Level 0-3       │
│                  │    │ Historian Mirror │    │                 │
│ Firewall ►       │    │     ▲ Firewall  │    │ ◄ Firewall      │
└──────────────────┘    └─────────────────┘    └─────────────────┘

Regras:
- Tráfego OT → IT: SEMPRE via DMZ (nunca direto)
- Tráfego IT → OT: PROIBIDO (exceto via jump host controlado)
- Data Diode: Permite dados apenas em UMA direção (OT → IT)
```

### 7.2 Unified Namespace (UNS)

Tendência Industry 4.0: **Namespace unificado** onde todos os dados (OT + IT) são publicados em tópicos hierárquicos MQTT/Sparkplug B.

```
Namespace hierárquico:
enterprise/
  site_sp/
    area_producao/
      linha_01/
        maquina_001/
          temperatura: 72.5
          velocidade: 1450
          status: "running"
          alarmes/
            over_temp: false
```

---

## 8. Dogmas

### NUNCA
- ❌ NUNCA conectar rede OT diretamente à internet
- ❌ NUNCA atualizar firmware de PLC remoto sem verificação presencial
- ❌ NUNCA ignorar o Purdue Model em ambientes industriais
- ❌ NUNCA usar protocolo sem criptografia entre OT e IT
- ❌ NUNCA chamar "dashboard de sensores" de Digital Twin
- ❌ NUNCA deployar modelo preditivo sem validação com dados reais

### SEMPRE
- ✅ SEMPRE implementar DMZ entre redes IT e OT
- ✅ SEMPRE usar OPC-UA para integração vertical multi-vendor
- ✅ SEMPRE versionar modelos de Digital Twin junto com dados de training
- ✅ SEMPRE validar Modbus endianness/word-swap com o datasheet do device
- ✅ SEMPRE ter fallback manual para controle (safety-critical)
- ✅ SEMPRE monitorar latência de control loops (Level 0-1 < 10ms)
