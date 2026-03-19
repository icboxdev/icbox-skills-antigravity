---
name: AWS Serverless Event-Driven Architecture (EDA)
description: Architect, scale, and validate Serverless architectures using AWS Lambda, API Gateway, Amazon SQS, and EventBridge. Enforces idempotent handlers, decoupled eventing, dead-letter queues (DLQs), and cold start mitigation.
---

# AWS Serverless Event-Driven Architecture (EDA)

Cargas de trabalho Serverless modernas na AWS não são meras "funções avulsas ligadas ao HTTP". Um verdadeiro sistema serverless opera usando *Event-Driven Architecture (EDA)* agressiva, desacoplamento asíncrono profundo, e resiliência via re-tentativas gerenciadas pelo plano de dados da AWS.

## 🏛️ Dogmas de Arquitetura AWS Serverless

1. **LAMBDAS EFFÊMERAS E STATELESS:** AWS Lambda mata sua "máquina" do nada após inativa (scale-to-zero) ou rodando por max 15m. NUNCA retenha estado em memória global contando que esteja ali na próxima invocação. OBRIGATÓRIO gerenciar persistência via DynamoDB, ElastiCache, ou S3. Armazene arquivos temporários exclusivamente em `/tmp`.
2. **DECOUPLING POR PADRÃO (EventBridge/SNSTopics):** Se o microsserviço A finalizar uma Venda e precisar notificar Serviço de Email (B) e Serviço de Estoque (C) usando requisições diretas API HTTP ou invokações Síncronas do Lambda O APP ESTÁ CONDENADO em escala ("Tight Coupling"). OBRIGATÓRIO Pub/Sub: Serviço A atira o evento `OrderPlaced` no "EventBridge Default Bus". Serviços B e C usinam regras customizadas em seus buckets independentes lendo da Bridge assincronamente.
3. **PULL (DLQ) CONTRA PERDA DE MENSAGENS E THROTTLE:** O SQS (Standard ou FIFO) atua como amortecedor elástico que absorve injeções de tráfego que poderiam matar bancos downstream. Contudo, mensagens que dão falha persistente NUNCA devem travar ou ser jogadas no limbo. OBRIGATÓRIO parear TODAS as filas AWS SQS ou EventBridge Mappings com *Dead-Letter Queues (DLQ)* atreladas. Analise-as depois sem dor.
4. **OTIMIZAÇÃO DE IDEMPOTÊNCIA MATEMÁTICA:** Num mundo EDA (Event-Driven), "Delivery is at-least-once". Sistemas como SQS distribuído entregam a mesma mensagem duas vezes quando a rede falha no Ack. Sua Lambda DEVE SER Idempotent (1 processo = Multiplos processos dão o mesmo saldo). OBRIGATÓRIO rastrear HashKeys assincronos processados ou validar o Update contra o DynamoDB Condicional (`attribute_not_exists(processed_msg_id)`).
5. **COLD START MITIGATION (O Fator Medo):** Em linguagens com runtimes pesados (Node Massivo, Java/C# sem AOT), a Lambda Freeza e demora 2s na primeira invocação. OBRIGATÓRIO mitigar isso compilando para Node com minificação Extrema via `esbuild`, removendo SDKs nativos obsoletos (AWS SDK v3 modular no Node 20+ incluso na layer), e gerenciando conexões de banco de dados (ex: manter Pool estático global FORA do escopo do Lambda handler).

## 🛑 Padrões (Certo vs Errado)

### EventBridge Publishing & Decoupling Extremo

**❌ ERRADO** (Sistema Monolítico na Lambda Síncrono Fragilizado):
```javascript
// order-lambda/index.js
export const handler = async (event) => {
   const order = await saveOrder(event.body);
   
   // PÉSSIMO: A venda falha pro usuário final e dá timeout 
   // SE o sistema de EMAIL demorar ou der erro 500.
   await axios.post('https://internal.erp/inventory/deduct', { id: order.id });
   await emailService.sendReceipt(order); 

   return { status: 200, body: 'Success' };
}
```

**✅ CERTO** (Atira evento pro EventBridge Cloud-native bus rápido. Tempo: ~50ms):
```javascript
import { EventBridgeClient, PutEventsCommand } from "@aws-sdk/client-eventbridge";
const ebClient = new EventBridgeClient({});

export const handler = async (event) => {
   const order = await saveOrder(event.body);
   
   // FIRE AND FORGET ELASTICO! 
   // Inventory e Email tem suas proprias lambdas ativadas por SQS Rule downstream via Bridge.
   await ebClient.send(new PutEventsCommand({
      Entries: [{
         Source: 'com.myempresa.order',
         DetailType: 'OrderPlaced',
         Detail: JSON.stringify({ orderId: order.id, total: order.total }),
         EventBusName: 'default'
      }]
   }));

   return { status: 200, body: 'Success' };
}
```

### Otimização Global vs Local de Banco de Dados (Postgres Pool)

**❌ ERRADO** (Cold Start + Exaustão de Conexão. Instanciar banco no Worker Handler):
```javascript
import pg from 'pg';

export const handler = async (event) => {
    // A CADA request de cliente numa máquina lambda quentinha, ele FAZ e QUEBRA o TCP conn handshake
    // 500 requests /s = 500 connections explodindo o Max_Connections do RDS PostgreSQL
    const client = new pg.Client({ string });
    await client.connect(); 
    const result = await client.query('...');
    await client.end();
}
```

**✅ CERTO** (Connection Pool no Global Scope Frozen da AWS):
```javascript
import pg from 'pg';
// Global Scope executado APENAS durante o COLD START! 
// Essa pool existirá "frozen" entre dezenas de acessos à mesma warm function aliviando o TCP/SSL overhead.
const pool = new pg.Pool({ connectionString: process.env.DB_URL, max: 1 });

export const handler = async (event) => {
    // Ultra rápido na Warm Function
    const result = await pool.query('SELECT * FROM users');
    return { status: 200, body: result.rows };
    // NUNCA de `pool.end()`. O ambiente cuidará disso ao ser obliterado pela AWS.
}
```
