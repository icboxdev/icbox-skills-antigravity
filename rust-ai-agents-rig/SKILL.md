---
name: Rust AI Agents (rig-core)
description: Architect, generate, and validate AI agents natively in Rust using rig-core. Enforces type-safe LLM outputs, robust Prompting, and Vector Database RAG integration without Python dependencies.
---

# Rust AI Agents (rig-core)

A implementação de LLMs em Rust utiliza o `rig-core`. Traz a força de multi-agentes de Langchain/LlamaIndex, porém com a robustez e checagens tipadas (Struct derivation) do Rust em compile-time. Você atua como Designer de Engenharia de IA.

## Arquitetura & Dogmas OBRIGATÓRIOS

- **Use `rig-core`**: Nunca tente abstrair verbos HTTP manuais para OpenAI/Anthropic. O Rig abstrai Providers nativamente suportando OpenAI, Cohere, Gemini.
- **Strictly Typed Outputs**: Sempre restrinja a resposta da LLM à extração estruturada (JSON/Schema) mapeando para uma Struct Rust anotada com `JsonSchema` e `Deserialize`. Evite textos livres onde dados são necessários.
- **Build Agents, Not Calls**: Construa `AgentBuilder` que mantém o contexto (System Prompt), temperamento e modelos associados, ao invés de enviar a configuração a cada `chat`.
- **Async Streaming Tolerante**: Quando lidando com Streaming back-to-client (SSE ou WebSockets), sempre implemente tratamentos para interrupção de socket e timeout do LLM via Tokio.

## Few-Shot: Extração Estruturada Type-Safe (Obrigatório)

### 🟢 CORRETO
```rust
use rig::{
    completion::Prompt,
    providers::openai::{Client, MODEL_GPT_4O},
};
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, JsonSchema, Debug)]
struct PersonMetadata {
    name: String,
    idade_estimada: u8,
    cargo: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    // 1. Cliente Tipado
    let client = Client::from_env();
    
    // 2. Criação do Agente Extrator
    let extractor = client.extractor::<PersonMetadata>(MODEL_GPT_4O).build();
    
    // 3. Extração (Result em Compile-time) - NADA de parse de strings
    let person: PersonMetadata = extractor
        .extract("Olá, sou o Akira, tenho 34 anos e atuo como Arquiteto de Software.")
        .await?;
        
    println!("Person: {:?}", person);
    Ok(())
}
```

### 🔴 ERRADO
```rust
use reqwest;
use serde_json::Value;

// Fazendo chamadas HTTP cruas para OpenAI e rezando pro JSON vir certo
async fn get_person() {
    let body = serde_json::json!({
        "model": "gpt-4",
        "messages": [{ "role": "user", "content": "Me dê um JSON do Akira de 34 anos Arquiteto." }]
    });
    
    let res = reqwest::Client::new().post("https://api.openai.com...").json(&body).send().await.unwrap();
    let val: Value = res.json().await.unwrap(); // PANIC SE MUDAR A API
}
```

## Few-Shot: Agent Builder Contextual

### 🟢 CORRETO
```rust
use rig::{providers::openai, agent::AgentBuilder};

async fn create_financial_agent(client: &openai::Client) -> Result<rig::agent::Agent<openai::CompletionModel>, anyhow::Error> {
    let agent = client
        .agent(openai::MODEL_GPT_4O)
        .preamble("Você é um analista financeiro estrito. Responda sempre em Markdown com Tabelas baseando-se em Fatos e nunca opine emocionalmente.")
        .temperature(0.1) // Baixa entropia em finanças
        .build();
        
    Ok(agent)
}
```

## RAG & Vector Stores

O Rig possui integração nativa em Rust para gerar embeddings (via Cohere/OpenAI) e persistir em Vector Stores. O uso do Padrão `VectorStoreIndex` deve ser atrelado ao `AgentBuilder::dynamic_context` sempre que se conectar o LLM a um banco de dados de conhecimento privado (Pinecone, Qdrant, etc).

## Context Management & Restrições Zero-Trust

- **Nunca** comite chaves como `OPENAI_API_KEY`. O método `Client::from_env()` extrairá em runtime.
- Como o `rig-core` tipa JSON em compile time usando a macro `#[derive(JsonSchema)]`, preste atenção para importar ambos traits (Serialize e Deserialize de serde).
- NUNCA envie mais Tokens que a janela da LLM, defina os máximos limitadores em caso práticos para se defender em produção.
