---
name: AWS RDS & Aurora Architecture
description: Architect, secure, and operate AWS RDS and Aurora Serverless v2 deployments emphasizing RDS Proxy, Multi-AZ failover, read replicas, and connection scaling strategies.
---

# AWS RDS & Aurora Architecture

O Amazon Aurora Serverless v2 altera o paradigma de dimensionamento de banco de dados, permitindo escalabilidade instantânea em instâncias fracionárias (ACUs). Para extrair a máxima performance e alta disponibilidade (HA) de ecossistemas AWS para bancos relacionais (PostgreSQL/MySQL), siga estes dogmas.

## 🏛️ Dogmas de Arquitetura AWS RDS/Aurora

1. **MULTI-AZ COMO OBRIGAÇÃO DE PRODUÇÃO:** NUNCA rode instâncias de produção em uma única Availability Zone. Para Aurora e RDS, ative Multi-AZ. No Aurora, o storage já é replicado 6 vezes em 3 AZs; mantenha ao menos um Reader em AZ distinta para permitir failover em menos de 60 segundos.
2. **INTERCEPTE TRÁFEGO COM RDS PROXY:** Aplicações modernas (especialmente Lambdas e ECS) abrem/fecham conexões rapidamente. OBRIGATÓRIO posicionar o AWS RDS Proxy entre a aplicação e o Aurora. O proxy gere o connection pool, realiza pin de conexões, e corta o tempo de failover em até 66% mascarando mudanças de DNS.
3. **NUNCA ESCALE ACUs PARA ZERO EM PRODUÇÃO:** Embora o Aurora Serverless v2 suporte escalar verticalmente em milissegundos, se a capacidade (ACU) cair muito, o buffer pool (memória) é ejetado. Evite Cold Starts de dados configurando o `Minimum ACU` para um valor que retenha o seu working set de dados na memória.
4. **SEPARE READ/WRITE ENDPOINTS:** O Aurora fornece um *Cluster Endpoint* (WRITER) e um *Reader Endpoint* (READERS com Load Balancing). Aplicações DEVEM rotear queries `SELECT` (reports, dashboards) para o Reader Endpoint, aliviando o nó Writer exclusivamente para mutações (INSERT, UPDATE).
5. **RESOLUÇÃO DE DNS E FAILOVER:** Em um evento de failover, o Aurora atualiza o CNAME do Cluster Endpoint. A aplicação DEVE usar TTL de DNS baixo (< 30s) e tratamento de reconexão (Retry with Exponential Backoff) para mitigar a janela de indisponibilidade momentânea, caso o RDS Proxy não seja utilizado.

## 🛑 Padrões (Certo vs Errado)

### Arquitetura de Conexões Serverless

**❌ ERRADO** (Conectar Lambdas diretamente ao Cluster Endpoint):
```json
// O Lambda abrirá centenas de conexões TCP, esgotando o limite do Aurora e causando ConnectionTimeouts.
{
  "DB_HOST": "my-aurora-cluster.cluster-xyz.eu-central-1.rds.amazonaws.com"
}
```

**✅ CERTO** (Conectar Lambdas via RDS Proxy):
```json
// O RDS Proxy absorve o pico, mantém pool de conexões persistentes com o Aurora 
// e acelera o failover sem que o Lambda perceba a queda do nó primário.
{
  "DB_HOST": "my-proxy.proxy-xyz.eu-central-1.rds.amazonaws.com"
}
```

### Tratamento e Separação de Rotas (Read/Write) no Código

**❌ ERRADO** (Rodar relatórios pesados no Writer):
```typescript
// Mesma conexão (Writer) para escrever e buscar relatórios analíticos
const client = db.connect(process.env.DB_CLUSTER_ENDPOINT);
await client.query("INSERT INTO orders...");
const heavyReport = await client.query("SELECT * FROM orders JOIN audit... GROUP BY..."); // SOBRECARREGA O WRITER!
```

**✅ CERTO** (CQRS em nível de banco, enviando leituras para a réplica):
```typescript
const writerPool = new Pool({ host: process.env.DB_CLUSTER_ENDPOINT });
const readerPool = new Pool({ host: process.env.DB_READER_ENDPOINT });

// Mutações rodam no Writer
await writerPool.query("INSERT INTO orders...");

// Relatórios pesados rodam em réplicas isoladas, sem impactar transações
const heavyReport = await readerPool.query("SELECT * FROM orders JOIN audit... GROUP BY...");
```

## 🔄 Topologia de Deploy Recomendada para 2024

1. **Aurora Serverless v2 Cluster:**
   - 1x Writer Instance (Min: 2 ACU, Max: 64 ACU) - AZ-a
   - 1x Reader Instance (Failover Tier 0, Min: 2 ACU, Max: 64 ACU) - AZ-b
2. **AWS RDS Proxy:** Associado ao Cluster, conectado à VPC.
3. **Application:** ECS Fargate ou Lambdas consumindo o Endpoint do RDS Proxy.
4. **Disaster Recovery (Opcional):** Aurora Global Database para replicar storage para outra região da AWS com latência de armazenamento < 1s.
