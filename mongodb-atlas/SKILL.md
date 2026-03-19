---
name: MongoDB Atlas & Cloud NoSQL
description: Architect, index, and optimize MongoDB Atlas cloud deployments enforcing dedicated Search Nodes, Vector Search integration, Multi-Cloud high availability, and Document Modeling best practices.
---

# MongoDB Atlas & Cloud NoSQL

MongoDB Atlas evoluiu de um banco NoSQL "Database as a Service" para uma "Unified Data Platform", abraçando Vector Search e AI pesadamente. A otimização em 2024 foca na separação de cargas de trabalho de busca e escala inteligente.

## 🏛️ Dogmas de Arquitetura MongoDB Atlas

1. **SEPARAÇÃO DE WORKLOADS (SEARCH NODES):** Para a maioria das aplicações usando 'Atlas Search' ou 'Vector Search', as queries operacionais (`.find()`) e as queries pesadas analíticas/vetoriais (`$search` / `$vectorSearch`) competem por RAM e CPU. OBRIGATÓRIO utilizar a arquitetura de **Dedicated Search Nodes**. Isso permite auto-scaling e sizing de hardware diferente para os motores de busca, sem derrubar a transacionalidade do DB.
2. **NUNCA ESCANEIE SEM ÍNDICES (COLLSCAN):** Em MongoDB, Collection Scans matam a latência e estouram a CPU da nuvem em segundos quando os dados crescem. OBRIGATÓRIO usar `explain("executionStats")` para garantir que toda operação transacional utilize B-Tree Indexes (Covered Queries idealmente).
3. **MODELAGEM POR ACESSO (O PADRÃO):** Ao invés de modelar normalizado (Relacional / 10 coleções minúsculas), o MongoDB exige modelar baseado na TELA/RESPOSTA que o app precisa fornecer. Se a entidade pai for deletada ou lida SEMPRE com suas dependências, EMBED os documentos. Se a array embutida puder crescer indefinidamente (Unbound Arrays: >1000 itens), NUNCA embute, REFERENCIE usando `ObjectId` (Parent-Referencing).
4. **UNIFIED PLATFORM PARA RAG:** Em sistemas generativos de IA, evite jogar Vetores num Pinecone e os Metadados transacionais num Relacional a menos que seja estritamente necessário. O Atlas Atlas Vector Search permite guardar o embedding (`[0.2, 0.45...]`) diretamente dentro do BSON no mesmo documento do usuário/contexto, sincronizando as mutações organicamente e buscando via `$vectorSearch`.
5. **MULTI-CLOUD DEPLOYMENTS (VENDEDOR AGNÓSTICO):** Para projetos corporativos com SLA ultra rígido ou para evitar Vendor Lock-in total, distribua os nós do Replica Set do Atlas por mais de um Cloud Provider simultaneamente (Ex: AWS us-east-1 + GCP us-east4). Falhas globais de uma nuvem disparam failovers para as demais.

## 🛑 Padrões (Certo vs Errado)

### Modelagem (Unbound Arrays vs Relacionamento)

**❌ ERRADO** (Array embutida que cresce sem parar - Causa quebra do limite de 16MB de BSON e lentidão):
```javascript
// A Collection 'IoTDevice' vai estourar rapidamente armazenando leituras infinitas na array interna.
{
  _id: ObjectId("5f1...123"),
  deviceName: "Sensor Termico C-10",
  logs_readings: [
     { temp: 22, time: "2024-01-01T..." },
     { temp: 23, time: "2024-01-01T..." },
     // ... 1.000.000 records depois -> BSON Limit Exceeded
  ]
}
```

**✅ CERTO** (Padrão Time Series ou Relacionamento Invertido / Bucketing):
```javascript
// Collection IoTDevice (Pai - Crescimento Lento)
{ _id: ObjectId("device-1"), name: "Sensor Termico" }

// Collection DeviceReadings (Filho/Bucketing - Crescimento Rápido)
{
  deviceId: ObjectId("device-1"), // Chave de indexação pesada
  day: "2024-01-01",
  readings: [ /* máx 1440 medições = 1 por min no dia (Bucketing) */ ]
}
```

### Pipelines de Integração RAG `$vectorSearch`

**❌ ERRADO** (Manter Coleções e Bancos de Vetores totalmente em silos com sync frágil):
1. Grava no MongoDB: `users.insertOne({ text: "meu contexto" })` -> Pula etapa
2. Grava no Banco XYV: Envia vetor pra API externa -> se a API 2 falhar, Inconsistência de Estado (State Inconsistency).

**✅ CERTO** (O Padrão Ouro do Atlas em Generative AI de 2024):
```javascript
// Aggregate com pre-filtering na mesma camada do database unificado
const results = await db.collection("knowledge_base").aggregate([
  {
    "$vectorSearch": {
      "index": "vector_index_name", // Index de HNSW Search Node
      "path": "content_embedding",
      "queryVector": [0.12, 0.45, ... ],
      "numCandidates": 100,
      "limit": 5,
      "filter": { "tenant_id": { "$eq": "corp-tenant-01" } } // Filtro nativo BSON = RLS
    }
  },
  {
    // Projection / Ocultando a array gigante de float do retorno
    "$project": { "content_embedding": 0, "score": { "$meta": "vectorSearchScore" } } 
  }
]).toArray();
```

## 🔄 Topologia Multi-Tenant Recomendada (SaaS)

Para ambientes MongoDB SaaS B2B, a arquitetura moderna evita o "Database-per-Tenant" caso tenha milhares de tenants (Limites de arquivos do WiredTiger Engine cobram preço alto em IOPS/RAM). Em vez disso:
- **Pool Management:** Crie UM ÚNICO CLUSTER Atlas auto-escalável.
- **Isolamento de Dados:** Insira e indexe `tenant_id` em todos os collections massivos. Crie Índices Compostos que INICIEM pelo `tenant_id` (`{ tenant_id: 1, created_at: -1 }`).
- **Dedicated Hardware (Opcional):** Se um Tenant for Enterprise tier gigantesco, realoque SOMENTE ELE para um Cluster Atlas dedicado via sharding isolado ou app-logic router.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

