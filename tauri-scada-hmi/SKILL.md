---
name: Tauri v2 Industrial HMI & SCADA
description: Architect, generate, and validate Tauri v2 applications operating as Industrial HMIs (Human-Machine Interfaces) or local SCADA nodes. Enforces offline-first resilience, Modbus/OPC-UA local polling, IPC high-frequency optimization, and OS Kiosk Mode lockdown.
---

# Tauri v2 Industrial HMI & SCADA Architecture

Esta skill define os dogmas para a construção de Interfaces Homem-Máquina (HMIs) e SCADAs locais rodando em Computadores Industriais (IPCs) ou painéis touch, utilizando **Tauri v2 (Rust + React)**.

Diferente do Web SCADA tradicional (acessado pela nuvem), a HMI Tauri roda fisicamente na planta, frequentemente offline, e comunica-se diretamente com os CLPs locais.

## 1. Kiosk Mode e Proteção do SO

A HMI não é um app desktop comum; ela é a única interface operacional lícita da máquina. O chão de fábrica **NUNCA** deve ter acesso à área de trabalho do sistema operacional subjacente.

1. **Window Config**: No `tauri.conf.json`, a janela principal DEVE estar configurada para simular um Kiosk Mode absoluto.

### Exemplo (Few-Shot): tauri.conf.json Kiosk

```json
// ❌ ERRADO: Janela desktop convencional com botões de fechar e bordas
{
  "windows": [{ "title": "HMI", "width": 800, "height": 600, "decorations": true }]
}

// ✅ CERTO: Configuração Kiosk / Computador de Painel IPC
{
  "windows": [
    {
      "title": "Industrial HMI",
      "fullscreen": true,
      "decorations": false,
      "alwaysOnTop": true,
      "resizable": false,
      "visible": true
    }
  ]
}
```

## 2. Gargalos de IPC na Telemetria (Performance)

O erro letal em HMIs Tauri é enviar telemetria bruta de alta frequência (ex: 1000 Hz) diretamente do Rust para o Frontend via eventos IPC. A serialização contínua de JSON para atravessar a ponte causará CPU Starvation e UI Freezes irreparáveis.

1. **Throttling e Batching Obrigatórios no Rust**: O Rust é quem suporta o tráfego pesado. Leia o Modbus na latência do robô (ex: 10ms), mas aglomere os dados (Batching) e envie para o React a no máximo **10Hz ~ 30Hz** (100ms a 33ms). A percepção humana de tela não processa acima de 30Hz com eficácia.

### Exemplo (Few-Shot): Emissão IPC de Alta Ocorrência

```rust
// ❌ ERRADO: Emitir evento para cada read do CLP (Congela o Event Loop)
loop {
    let val = plc.read_holding_registers(0, 1).await?;
    app.emit_all("sensor_update", val[0]).unwrap(); // Sobrecarga IPC
    tokio::time::sleep(Duration::from_millis(5)).await;
}

// ✅ CERTO: Coleta rápida no Rust, flushing throttled em batch (Ex: a 10Hz)
let mut buffer = Vec::new();
let mut interval = tokio::time::interval(Duration::from_millis(100)); // 10Hz Batch

loop {
    tokio::select! {
        Ok(val) = plc.read_holding_registers(0, 1) => {
            buffer.push(val[0]); // Rust aloca a carga bruta passivamente 
        }
        _ = interval.tick() => {
            if !buffer.is_empty() {
                // Emissão única contendo dezenas de pontos. Menos serialização.
                app.emit_all("sensor_batch", &buffer).unwrap();
                buffer.clear();
            }
        }
    }
}
```

## 3. Arquitetura Edge Offline-First (Store-and-Forward)

Redes em linhas de produção são insalubres. A HMI Tauri freqüentemente perde conexão com o centralizador de telemetria na nuvem, e NADA pode ser perdido.

1. **Embedded DB**: O backend Rust atua como Master Buffer usando SQlite (`sqlx`) para gravar TUDO localmente no momento da leitura.
2. **Cloud Sync Assíncrono**: Uma Task Tokio no background varre a rede; se online, descarrega local → AWS/Postgres (TimescaleDB) em batch-inserts.

### Exemplo (Few-Shot): Dogma de I/O em Frontend

**DOGMA**: O React na HMI não sabe o que é a nuvem.

```typescript
// ❌ ERRADO: O React tentando enviar HTTP Request para a AWS (Falha no Wi-Fi industrial)
await fetch("https://scada-cloud.com/api/ingest", { body: JSON.stringify(data) });

// ✅ CERTO: O React invoca a gravação atômica no Rust Local (Localhost IPC).
await invoke("store_telemetry_local_and_queue", { data });
```

## 4. Segurança do Edge HMI (Princípio do Privilégio Mínimo)

Mesmo num PC de fábrica blindado (sem teclado), a segurança da `WebView` contra injeção no touch (exemplo, injetar um payload se houver um text-input mal sanitizado) é crítica.

1. **Isolation Pattern Rigoroso**: Obrigatoriedade de interceptação via `isolation` security mode do Tauri v2.
2. **Capabilities Microscópicas**: O HMI precisa exportar relatório CSV? Crie uma diretriz `fs:write` **estritamente atrelada à pasta de exports**, NUNCA ative permissões genéricas do disco. Um touch mal intencionado nunca poderá invocar `System32` ou `/bin/bash` por herança IPC corrupta.

## 5. Diretriz de Scripts Temporários

Quaisquer mocks criados pelo desenvolvedor/IA (ex: simuladores Modbus em Node.js ou Python gerando ruído para testar a ponte IPC do Tauri) **DEVEM ser postados explicitamente na pasta global temporária do OS** (`/tmp/` ou `%TEMP%`).

- ❌ Não hospede "Mocks industriais de teste" na pasta `./src-tauri`.
- Limpe o cenário após o teste atuar.
