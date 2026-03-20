---
name: IoT Security & Zero Trust
description: Architect, validate, and enforce IoT security patterns covering device authentication (mTLS, X.509, TPM), data encryption (TLS 1.3, AES-256), secure boot, firmware signing, OTA update security, network micro-segmentation, Zero Trust device identity, and OWASP IoT Top 10 mitigation. Concept-focused, stack-agnostic.
---

# IoT Security & Zero Trust — Diretrizes Senior+

## 1. Princípio Fundamental

IoT é o maior vetor de ataque da década. Devices com firmware desatualizado, credenciais hardcoded e comunicação sem criptografia são **bombas-relógio**. Segurança IoT é "secure by default" ou é fracasso.

> ⚠️ "Está atrás do firewall" NÃO é segurança. Todo device é um potencial ponto de entrada. Zero Trust sempre.

---

## 2. OWASP IoT Top 10 — Mitigações Obrigatórias

| # | Vulnerabilidade | Mitigação |
|---|---|---|
| 1 | **Weak/Guessable Passwords** | Credenciais únicas por device. NUNCA default password |
| 2 | **Insecure Network Services** | Desabilitar portas/serviços não utilizados. Firewall no device |
| 3 | **Insecure Ecosystem Interfaces** | API Gateway com auth, rate limiting, input validation |
| 4 | **Lack of Secure Update** | OTA com firmware assinado + rollback + staged rollout |
| 5 | **Insecure/Outdated Components** | SBOM (Software Bill of Materials), CVE monitoring |
| 6 | **Insufficient Privacy Protection** | Encryp data at rest, minimize PII collection |
| 7 | **Insecure Data Transfer** | TLS 1.3 obrigatório. NUNCA plaintext em produção |
| 8 | **Lack of Device Management** | Device registry, lifecycle tracking, remote wipe |
| 9 | **Insecure Default Settings** | Secure defaults: portas fechadas, debug desabilitado |
| 10 | **Lack of Physical Hardening** | Tamper detection, secure boot, disable JTAG/UART |

---

## 3. Device Authentication — Pirâmide de Confiança

### 3.1 Níveis de Autenticação

```
Nível 4: mTLS + TPM + Certificate Rotation
├── Certificado X.509 armazenado em hardware seguro (TPM/SE)
├── Mutual TLS: device E server se autenticam mutuamente
├── Rotação automática de certificados
└── Para: Industrial, Healthcare, Critical Infrastructure

Nível 3: mTLS com certificado em software
├── Certificado X.509 no filesystem
├── Mutual TLS
└── Para: Gateways, Edge servers

Nível 2: API Key + TLS
├── API Key única por device (prefixo indexável)
├── TLS 1.3 para transporte
├── Timing-safe comparison no server
└── Para: Sensores com capacidade limitada de crypto

Nível 1: Pre-Shared Key (PSK)
├── Chave simétrica provisionada na fábrica
├── DTLS para CoAP
└── Para: Devices ultra-constrained

Nível 0: Sem autenticação ← PROIBIDO em produção
```

### 3.2 Regras de Autenticação

```
CERTO: Identidade única por device
┌── Factory ─────────────────────┐
│ Device MAC: AA:BB:CC:DD:EE:FF  │
│ Cert: /certs/device_001.pem    │ ← Certificado ÚNICO
│ Private Key: TPM Slot 0        │ ← Chave NUNCA sai do hardware
└────────────────────────────────┘

ERRADO: Credencial compartilhada
┌── Factory ──────────────────────┐
│ Device 001: API_KEY=shared_key  │ ← MESMO key
│ Device 002: API_KEY=shared_key  │ ← para TODOS
│ Device 003: API_KEY=shared_key  │ ← comprometeu 1 = comprometeu TODOS
└─────────────────────────────────┘
```

---

## 4. Encryption — Data in Transit & at Rest

### 4.1 In Transit (Obrigatório)

| Protocolo App | Transporte Seguro | Porta | Requisito |
|---|---|---|---|
| MQTT | TLS 1.3 (MQTTS) | 8883 | Certificado server + client |
| CoAP | DTLS 1.2+ | 5684 | PSK ou Certificate |
| HTTP | TLS 1.3 (HTTPS) | 443 | Certificado server |
| WebSocket | WSS (TLS) | 443 | Certificado server |
| Modbus TCP | VPN/TLS tunnel | — | Encapsulamento obrigatório |

### 4.2 At Rest

- **Dados sensíveis no device**: AES-256-GCM (se o hardware suportar)
- **Devices constrained**: ChaCha20-Poly1305 (mais leve que AES sem AES-NI)
- **Cloud storage**: Encryption at rest habilitado no provider
- **Chaves criptográficas**: NUNCA armazenar junto com os dados que protegem

---

## 5. Secure Boot & Firmware Integrity

### 5.1 Chain of Trust

```
ROM Bootloader (imutável)
  │
  ├── Verifica assinatura do 1st stage bootloader
  │     │
  │     ├── Verifica assinatura do firmware principal
  │     │     │
  │     │     ├── Firmware executa
  │     │     └── Se falha → Rollback para firmware anterior
  │     └── Se falha → BRICK (device não inicia)
  └── Se falha → Device não inicia (proteção contra tamper)
```

### 5.2 Regras de Firmware

- Todo firmware DEVE ser **digitalmente assinado** (RSA-2048+ ou ECDSA P-256)
- A **chave pública** de verificação é gravada no device na fábrica
- A **chave privada** de assinatura fica em HSM seguro no build server
- NUNCA distribuir firmware sem assinatura
- NUNCA armazenar chave privada de assinatura em repositório de código

---

## 6. OTA (Over-the-Air) Update — Segurança

### 6.1 Pipeline Seguro de OTA

```
Build Server (CI/CD)
  │
  ├── 1. Compilar firmware
  ├── 2. Assinar com chave HSM
  ├── 3. Gerar checksum SHA-256
  ├── 4. Publicar em CDN/Object Storage
  │
Device
  │
  ├── 5. Verificar disponibilidade de update
  ├── 6. Download com TLS
  ├── 7. Verificar assinatura digital
  ├── 8. Verificar checksum
  ├── 9. Flash para partição secundária (A/B)
  ├── 10. Reboot na nova partição
  ├── 11. Health check pós-boot
  │     ├── OK → Confirmar update, marcar partição como ativa
  │     └── FAIL → Rollback automático para partição anterior
  └── 12. Reportar resultado ao server
```

### 6.2 Regras de OTA

- ✅ **Dual-bank (A/B) partitioning**: SEMPRE ter partição de fallback
- ✅ **Delta updates**: Enviar apenas diferenças (reduz bandwidth)
- ✅ **Staged rollout**: 1% → 5% → 25% → 100% das frotas
- ✅ **Health check pós-update**: Confirmar que device está funcional
- ❌ NUNCA forçar update sem opção de rollback
- ❌ NUNCA atualizar firmware sem verificar assinatura e checksum
- ❌ NUNCA atualizar 100% da frota de uma vez

---

## 7. Zero Trust para IoT

### 7.1 Princípios

1. **Never Trust, Always Verify**: Toda comunicação é verificada, mesmo dentro da rede
2. **Least Privilege**: Device só acessa recursos necessários para sua função
3. **Assume Breach**: Projetar como se a rede já estivesse comprometida
4. **Continuous Verification**: Revalidar identidade e autorização continuamente

### 7.2 Implementação Prática

```
┌── Network Segmentation (Micro-segmentation) ──────┐
│                                                     │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐          │
│  │ VLAN    │   │ VLAN    │   │ VLAN    │          │
│  │ Sensors │   │ Cameras │   │ HVAC    │          │
│  │ (RO)    │   │ (RO)    │   │ (R/W)   │          │
│  └────┬────┘   └────┬────┘   └────┬────┘          │
│       │              │              │               │
│  ┌────▼──────────────▼──────────────▼────┐          │
│  │    IoT Gateway (Policy Enforcement)    │          │
│  │    - Device certificate validation     │          │
│  │    - Topic-level ACL per device        │          │
│  │    - Anomaly detection (behavior)      │          │
│  └───────────────────┬───────────────────┘          │
│                      │                              │
└──────────────────────┼──────────────────────────────┘
                       │ TLS 1.3
                  ┌────▼────┐
                  │  Cloud  │
                  │ (mTLS)  │
                  └─────────┘
```

### 7.3 ACL por Device (Topic-Level)

```
# CERTO: ACL granular por device
Device MAC=AA:BB:CC
  PUBLISH:   telemetry/{tenant}/{mac}/+     ← só SEU tópico
  SUBSCRIBE: commands/{tenant}/{mac}/+      ← só SEUS comandos
  DENY:      telemetry/{tenant}/OTHER_MAC/+ ← NUNCA dados de outros

# ERRADO: Acesso amplo
Device MAC=AA:BB:CC
  PUBLISH:   telemetry/#     ← acesso a TUDO
  SUBSCRIBE: commands/#      ← recebe TODOS os comandos
```

---

## 8. Physical Security

- **Disable debug interfaces** em produção (JTAG, UART, SWD)
- **Tamper detection**: Sensor de abertura do enclosure → zerar keys
- **Secure enclosure**: Parafusos anti-tamper, resina epóxi em PCB
- **Fuse bits**: Bloquear leitura de flash após programação
- **Side-channel protection**: Countermeasures contra power analysis

---

## 9. Dogmas Inegociáveis

### NUNCA
- ❌ NUNCA usar credenciais default em produção
- ❌ NUNCA transmitir dados sem TLS/DTLS
- ❌ NUNCA armazenar chaves privadas em código-fonte
- ❌ NUNCA usar firmware sem assinatura digital
- ❌ NUNCA deixar portas de debug habilitadas em produção
- ❌ NUNCA compartilhar a mesma credencial entre múltiplos devices
- ❌ NUNCA ignorar CVEs em dependências do firmware

### SEMPRE
- ✅ SEMPRE usar identidade única por device (MAC + cert)
- ✅ SEMPRE implementar secure boot chain of trust
- ✅ SEMPRE ter mecanismo de rollback de firmware
- ✅ SEMPRE segmentar rede por tipo/função de device
- ✅ SEMPRE logar tentativas de autenticação (sucesso e falha)
- ✅ SEMPRE rotacionar credenciais periodicamente
- ✅ SEMPRE manter SBOM atualizado para cada firmware version
