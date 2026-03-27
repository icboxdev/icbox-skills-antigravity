---
name: IoT Device Lifecycle Management
description: Architect, validate, and enforce IoT device lifecycle patterns covering provisioning (zero-touch, certificate-based), fleet management, Device Twin/Shadow synchronization, OTA firmware orchestration, remote diagnostics, decommissioning, and compliance-driven retirement. Concept-focused, stack-agnostic.
---

# IoT Device Lifecycle Management — Diretrizes Senior+

## 1. Princípio Fundamental

Um device IoT sem gerenciamento de lifecycle é um **liability**, não um asset. Do provisionamento à aposentadoria, cada estágio deve ser controlado, auditável e automatizável.

> ⚠️ Se você não consegue responder "quantos devices estão online agora, qual firmware rodam, e quando foi o último update", seu gerenciamento de lifecycle falhou.

---

## 2. Device Lifecycle — Estágios

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│PLANNING  │───→│PROVISION │───→│OPERATION │───→│MAINTAIN  │───→│DECOMM.   │
│ Design   │    │ Register │    │ Monitor  │    │ OTA      │    │ Wipe     │
│ Procure  │    │ Config   │    │ Telemetry│    │ Diagnose │    │ Recycle  │
│ Certify  │    │ Deploy   │    │ Command  │    │ Repair   │    │ Audit    │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
       │              │              │              │              │
       └──────────────┴──────────────┴──────────────┴──────────────┘
                       Device Registry (Single Source of Truth)
```

---

## 3. Provisioning — Onboarding Seguro

### 3.1 Métodos de Provisioning

| Método | Automação | Segurança | Escala | Quando Usar |
|---|---|---|---|---|
| **Manual** | ❌ | Média | < 10 | Protótipos, lab |
| **QR/Barcode Scan** | Parcial | Média | < 100 | Retail, consumer |
| **Provisioning by Claim** | ✅ Auto | Alta | 100-10K | Fleet deployment |
| **Zero-Touch (cert-based)** | ✅ Full | Muito alta | 10K+ | Industrial, enterprise |

### 3.2 Zero-Touch Provisioning Flow

```
┌─ Factory ──────────────────────────────────┐
│ 1. Gravar certificado único + chave no TPM │
│ 2. Registrar MAC + cert fingerprint no     │
│    Device Registry (cloud)                 │
│ 3. Flash firmware com bootstrap config     │
└────────────────────────────────────────────┘
           │
           ▼
┌─ Field Deployment ─────────────────────────┐
│ 4. Device liga, conecta via bootstrap      │
│ 5. mTLS handshake com cloud                │
│ 6. Cloud valida cert → busca config        │
│ 7. Device recebe config final (endpoints,  │
│    sampling rates, OTA server)             │
│ 8. Status: PROVISIONED → ONLINE            │
└────────────────────────────────────────────┘
```

### 3.3 Regras de Provisioning

- ✅ Cada device DEVE ter identidade única (MAC + cert/key)
- ✅ Provisioning DEVE ser idempotente (re-provisionar não quebra)
- ✅ Config sensível NUNCA hardcoded — injetada via provisioning
- ❌ NUNCA enviar credenciais via canal inseguro (HTTP, SMS)
- ❌ NUNCA usar mesma credencial para provisioning e operação

---

## 4. Device Twin / Device Shadow

### 4.1 Conceito

Device Twin é a **representação virtual** do device no cloud, mantendo:
- **Reported State**: Estado atual reportado PELO device
- **Desired State**: Estado desejado definido PELA aplicação
- **Metadata**: Timestamps, versões, connectivity status

```
┌── Cloud (Device Twin) ────────────────┐
│                                       │
│  Desired:  { "interval": 30,          │
│              "firmware": "2.1.0" }     │
│                                       │
│  Reported: { "interval": 60,          │  ← Diferença = AÇÃO PENDENTE
│              "firmware": "2.0.5" }     │
│                                       │
│  Metadata: { "lastSeen": "...",       │
│              "connected": true }       │
└───────────────────────────────────────┘
```

### 4.2 Sync Protocol

```
1. App define Desired State no Twin
2. Cloud detecta diff (Desired ≠ Reported)
3. Cloud envia delta para device (via MQTT/WS)
4. Device aplica mudança
5. Device atualiza Reported State no Twin
6. Cloud confirma sync (Desired == Reported)

Se device OFFLINE:
- Desired State fica pendente no Twin
- Quando device reconecta → recebe delta acumulado
- Device aplica e reporta → sync completo
```

### 4.3 Regras do Device Twin

- ✅ Twin é a source of truth para estado DESEJADO
- ✅ Device é a source of truth para estado REAL
- ✅ Toda mudança de config passa pelo Twin (auditável)
- ❌ NUNCA modificar device diretamente sem atualizar Twin
- ❌ NUNCA confiar no Reported se lastSeen > threshold

---

## 5. Fleet Management

### 5.1 Conceitos de Fleet

- **Fleet**: Grupo de devices gerenciados coletivamente
- **Device Group**: Subconjunto por critério (modelo, localização, firmware)
- **Job**: Operação executada em grupo (OTA, config change, reboot)
- **Policy**: Regra automática aplicada ao fleet (auto-update, quarantine)

### 5.2 Fleet KPIs Obrigatórios

| KPI | Descrição | Target | Alerta |
|---|---|---|---|
| **Online Rate** | % de devices conectados | > 95% | < 85% |
| **Firmware Currency** | % na versão mais recente | > 90% | < 70% |
| **Update Success Rate** | % de OTA bem-sucedidos | > 98% | < 90% |
| **Alert Acknowledgment** | Tempo médio para ACK | < 15 min | > 1h |
| **MTTR** | Mean Time to Recovery | < 4h | > 24h |
| **Orphan Devices** | Devices sem check-in recente | 0 | > 5% |

### 5.3 Fleet Operations Pattern

```
┌── Fleet Operation: OTA Update ─────────────────┐
│                                                 │
│  1. Definir target group (by tag, model, etc.)  │
│  2. Criar Job: "update-fw-2.1.0"                │
│  3. Staged rollout: canary (1%) → expand        │
│  4. Monitor success rate em cada stage           │
│     ├── Success > 98% → next stage              │
│     └── Success < 90% → HALT + investigate      │
│  5. Mark complete quando 100% done              │
│  6. Gerar report: success, failures, rollbacks  │
└─────────────────────────────────────────────────┘
```

---

## 6. Remote Diagnostics

### 6.1 Capacidades Obrigatórias

Todo device gerenciável DEVE suportar:

1. **Health Check**: Report de CPU, RAM, disk, temperatura
2. **Log Retrieval**: Coleta remota de logs do device
3. **Network Diagnostics**: Ping, traceroute, connection quality
4. **Reboot**: Comando remoto de restart
5. **Factory Reset**: Restore config padrão (com confirmação)
6. **Shell Access**: Acesso remoto seguro (SSH tunnel ou WebSocket)

### 6.2 Diagnostics via Device Twin

```
# Solicitar diagnóstico
Desired: { "diagnostics": { "type": "health", "requestId": "abc" } }

# Device responde
Reported: { "diagnostics": {
  "requestId": "abc",
  "cpu": 45,
  "ram_mb": 128,
  "disk_pct": 67,
  "temp_c": 52,
  "uptime_s": 864000
}}
```

---

## 7. Decommissioning — Aposentadoria Segura

### 7.1 Checklist de Decommissioning

```
1. ☐ Revogar certificados/API keys do device
2. ☐ Remover device do registry
3. ☐ Apagar Device Twin/Shadow
4. ☐ Parar cobrança de licença/SIM
5. ☐ Wipe dados sensíveis do device (factory reset)
6. ☐ Desabilitar SIM card (se celular)
7. ☐ Atualizar inventário/asset register
8. ☐ Gerar audit log de decommissioning
9. ☐ Descarte físico seguro (WEEE compliance)
```

---

## 8. Dogmas

### NUNCA
- ❌ NUNCA perder rastreabilidade de um device (registry é sagrado)
- ❌ NUNCA fazer OTA sem rollback automático
- ❌ NUNCA atualizar fleet inteiro de uma vez (staged rollout)
- ❌ NUNCA desconsiderar devices offline no planejamento de OTA
- ❌ NUNCA descartar device sem wipe de credenciais

### SEMPRE
- ✅ SEMPRE ter Device Registry como source of truth
- ✅ SEMPRE implementar Device Twin para sync bidirecional
- ✅ SEMPRE monitorar heartbeat com threshold de offline
- ✅ SEMPRE manter log de todas as operações de fleet
- ✅ SEMPRE ter processo documentado de decommissioning
