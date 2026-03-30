---
name: AWS Lambda Rust Serverless
description: Architect, compile, and validate Rust functions for AWS Lambda using cargo-lambda and axum-aws-lambda. Enforces cold-start minimization, LambdaEvent processing, and Edge computing paradigms.
---

# AWS Lambda Rust Serverless

Deploying Rust in AWS Lambda (or any compatible edge provider) provides minimal cold starts (sub-10ms), zero-cost abstractions, and memory safety. You act as an expert Serverless Architect using Rust.

## Arquitetura & Dogmas OBRIGATÓRIOS

- **Use `cargo-lambda`**: NUNCA tente compilar Rust para Lambda manualmente com zig/musl target sem a toolchain do `cargo-lambda`. É o padrão ouro.
- **Interoperabilidade com Axum**: Ao portar APIs completas, use `axum-aws-lambda` e `lambda-http`. Isso reaproveita 100% da arquitetura Axum, bastando alterar a inicialização.
- **Event-Driven**: Para processamento de SQS/EventBridge, não use `lambda-http` e sim `lambda_runtime` consumindo a struct `LambdaEvent<Payload>`.
- **Initialization Scope**: O que é executado FORA do loop `lambda_runtime::run` é cacheado ao longo do ciclo de vida da Lambda. Inicialize pools do banco e clients HTTP *antes* de rodar o loop.
- **Tolerância à falha (Zero-Trust)**: Cada invocação da lambda DEVE tratar erros isoladamente e não usar `.unwrap()`, sob o risco de derrubar (crash) o processo worker na AWS.

## Few-Shot: Axum em Serverless Edge

### 🟢 CORRETO
```rust
use axum::{routing::get, Router};
use lambda_http::{run, tracing, Error}; // Dependências específicas de Serverless

// Inicialização rápida e limpa
#[tokio::main]
async fn main() -> Result<(), Error> {
    // 1. Tracing otimizado para CloudWatch
    tracing::init_default_subscriber();
    
    // 2. Setup Pesado fora do request (Conexões, Clients HTTP) fica cacheado
    let app = Router::new().route("/", get(|| async { "Hello from AWS Lambda + Axum!" }));
    
    // 3. O Loop de Runtime da Lambda! NUNCA use axum::serve() num ambiente serverless.
    run(app).await
}
```

### 🔴 ERRADO
```rust
use axum::{routing::get, Router};
// Faltam imports da lambda

#[tokio::main]
async fn main() {
    let app = Router::new().route("/", get(|| async { "Hello App" }));
    // Pânico: Tentando fazer bind() manual de porta (não há listener nativo na Lambda)
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

## Few-Shot: Processador SQS (Event-Driven Native)

### 🟢 CORRETO
```rust
use lambda_runtime::{run, service_fn, Error, LambdaEvent};
use aws_lambda_events::event::sqs::SqsEvent;
use serde_json::Value;

async fn function_handler(event: LambdaEvent<SqsEvent>) -> Result<Value, Error> {
    let (payload, _context) = event.into_parts();

    // Processar mensagens em lote
    for record in payload.records {
        if let Some(body) = record.body {
            println!("Processando SQS ID {}: {}", record.message_id.unwrap_or_default(), body);
        }
    }
    
    // Sucesso ou Idempotency, DLQ será acionado em falha propagada
    Ok(serde_json::json!({ "status": "processed", "count": payload.records.len() }))
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_ansi(false) // ANSI breaks CloudWatch formatting
        .init();

    run(service_fn(function_handler)).await
}
```

## Dependências Universais e `cargo-lambda`

Se precisar gerar um novo projeto, SEMPRE execute:
`cargo lambda new project-name`

E sempre inclua o feature de AWS SDK onde cabível se comunicar com S3/Dynamo. Nunca construa clientes S3 na mão.

## Context Management & Restrições Zero-Token

- Não perca tempo lendo grandes manuais da AWS se a task for simples. Utilize o SDK via blocos limitados e concisos.
- Restrinja o escopo dos testes locais (Unit tests não batem na flag `--release`, lembre-se). Use `cargo lambda watch` apenas se estritamente solicitado pelo USER.
