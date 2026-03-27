---
name: Modbus Protocol & Async Rust Implementation Mastery
description: Architect, generate, and validate Modbus communication (TCP/RTU) encompassing the strict Data Model, Endianness/Word Swapping, Exception Handling, and high-performance async Rust implementations utilizing `tokio-modbus` and asynchronous I/O isolation.
---

# Modbus Protocol & Async Rust Implementation Mastery

Esta skill dita o dogmatismo arquitetural para implementações do protocolo Modbus (TCP/IP e Serial RTU) utilizando Rust Assíncrono (`tokio`, `tokio-modbus`). Todo desenvolvimento envolvendo automação industrial, leituras de CLP (PLC) e gateways M2M deve seguir estas regras rigorosamente.

## Protocol Dogmas (Zero-Trust Modbus)

1. **Separação PDU vs ADU**: A lógica de aplicação lida com o *Protocol Data Unit* (Function Code + Data). O transporte (TCP MBAP header ou RTU CRC) deve ser estritamente delegado à camada inferior (`tokio-modbus`).
2. **Respeito aos Limites de Leitura/Escrita**:
   - Escrita Múltipla (FC16): Máximo absoluto de **123** Holding Registers por request.
   - Leitura Múltipla (FC03/FC04): Máximo absoluto de **125** registradores por request.
   - *Nunca* crie loops infinitos sem paginação (chunking) ao ler datasets longos.
3. **Data Model Estrito**:
   - `Coils` (0x): Leitura/Escrita (1 bit).
   - `Discrete Inputs` (1x): Somente Leitura (1 bit).
   - `Input Registers` (3x): Somente Leitura (16 bits) — Valores analógicos de sensores.
   - `Holding Registers` (4x): Leitura/Escrita (16 bits) — Configurações e setpoints.
4. **Exception Handling Obrigatório**:
   - Você DEVE tratar ativamente os códigos de erro padrão Modbus: `01` (Illegal Function), `02` (Illegal Data Address), `03` (Illegal Data Value), `04` (Server Device Failure). *Nunca* trate erro Modbus como um simples `unwrap()`.

## Endianness & Composite Types (A Regra de Ouro)

O Modbus transmite dados nativamente em **Big-Endian (Network Byte Order)** para registradores de 16-bits. No entanto, tipos compostos (UInt32, Float32, Double) exigem 2 ou 4 registradores, e não há padronização oficial.

**Dogma de Payload**:  
Você **NUNCA DEVE** assumir o byte-order de um Float32 sem parametrizar o "Word Swap" ou "Byte Swap". Sempre exija a documentação do mapa de registradores do dispositivo alvo.
- Padrões conhecidos: `CDAB` (Word Swap / Little-Endian Mid-Big), `ABCD` (Big-Endian), `BADC` (Byte Swap), `DCBA` (Little-Endian).

### Exemplo (Few-Shot): Decode Float32
```rust
// ❌ ERRADO: Assumir casting direto ou ignorar o layout em memória
let data: [u16; 2] = [0x42f6, 0xe666]; // Representa 123.45 em Float32
let val = data[0] as f32; // Incorreto!

// ✅ CERTO: Decode explícito padrão ABCD (Big-Endian word order)
let data: [u16; 2] = [0x42f6, 0xe666];
let bytes = [
    (data[0] >> 8) as u8, (data[0] & 0xFF) as u8,
    (data[1] >> 8) as u8, (data[1] & 0xFF) as u8,
];
let val = f32::from_be_bytes(bytes);

// ✅ CERTO: Decode explícito padrão CDAB (Word Swap - Comum na Indústria)
let bytes = [
    (data[1] >> 8) as u8, (data[1] & 0xFF) as u8,
    (data[0] >> 8) as u8, (data[0] & 0xFF) as u8,
];
let val = f32::from_be_bytes(bytes);
```

## Tokio Architectural Dogmas (Concorrência & I/O)

O uso de `tokio` e `tokio-modbus` exige engenharia focada na prevenção de *Event Loop Starvation* e *Hung Tasks*.

1. **Prevenção de I/O Infinito (Timeouts)**:
   A rede de chão de fábrica (OT) é hostil. Dispositivos desligam ou sofrem interferência (EMI).
   **NENHUMA** chamada de leitura/escrita externa deve ser feita sem o invólucro de `tokio::time::timeout`.
2. **Desacoplamento de Estado (Concurrency Isolation)**:
   Em emuladores/servidores Modbus, o mapa de memória do equipamento é frequentemente compartilhado entre a Thread TCP e a Thread de Mutações (ex: simulação de sensores do mundo físico).
   Use `Arc<tokio::sync::Mutex<RegisterMap>>` se a contenção for pequena, ou `RwLock` para cenários "Read-Heavy".
3. **Desacoplamento TCP (mpsc)**:
   Nunca travar um loop principal esperando por I/O. Processe a lógica pesada e comunique-se via `mpsc` em bound channels.

### Exemplo (Few-Shot): Fault-Tolerant Network Call
```rust
// ❌ ERRADO: Chamada direta síncrona/assíncrona que pode travar a task ad-infinitum
let response = client.read_holding_registers(0, 10).await.unwrap();

// ✅ CERTO: Invólucro com timeout restrito e tratamento adequado de exceções
use std::time::Duration;
use tokio::time::timeout;

match timeout(Duration::from_millis(500), client.read_holding_registers(0, 10)).await {
    Ok(Ok(response)) => {
        // I/O Sucesso, Response Sucesso
        println!("Registers: {:?}", response);
    }
    Ok(Err(modbus_err)) => {
        // I/O Sucesso mas Slave retornou erro (Exceção FC) ou falha de protocolo
        tracing::warn!("Modbus exception: {}", modbus_err);
    }
    Err(_) => {
        // Timeout (Device Offline / Cabos Partidos)
        tracing::error!("Timeout: Dispositivo não respondeu após 500ms");
    }
}
```

## Diretriz de Scripts Temporários

Quaisquer scripts utilitários ou de testes criados rapidamente para debug desta infraestrutura (ex: `test_endianness.py`, `simulate_noise.sh`) DEVEM ser colocados no diretório `/tmp/` da máquina host e removidos após uso, jamais sujando a árvore do repositório principal do projeto.
