---
name: Vector Databases & RAG Pipelines
description: Architect, index, and optimize Vector Databases (Pinecone, pgvector, Weaviate, Milvus) enforcing HNSW/IVFFlat indexing strategies, embeddings compression, and advanced Retrieval-Augmented Generation (RAG) best practices.
---

# Vector Databases & RAG Pipelines

Bancos de dados vetoriais não são apenas armazenamentos comuns; eles persistem Matemática de Alta Dimensionalidade (Embeddings) e dependem de algoritmos de Approximate Nearest Neighbor (ANN) para busca semântica em frações de segundo.

## 🏛️ Dogmas de Arquitetura Vetorial & RAG

1. **NÃO BUSQUE, RECUPERE (RAG Strategy):** O modelo RAG de 2024 exige Pipeline de Recuperação Avançada. OBRIGATÓRIO utilizar técnicas de "Chunking" semântico (dividir documentos não apenas por limite de tokens, mas por significado/parágrafos) antes do embedding. NUNCA gere embeddings de documentos inteiros; o sinal se dilui em ruído.
2. **HNSW COMO PADRÃO-OURO (Recall vs Speed):** Se a memória RAM permitir, utilize o index **HNSW** (Hierarchical Navigable Small World) ao invés do clássico **IVFFlat**. HNSW entrega altíssimo recall e busca sub-milissegundo, sendo resiliente a datasets dinâmicos (onde dados entram constantemente). IVFFlat exige treinamento de clusters e re-indexação se a distribuição dos dados mudar fortemente.
3. **METADATA É TÃO IMPORTANTE QUANTO VETORES:** Uma busca 100% vetorial é ineficiente em cenários corporativos. Projetos reais OBRIGAM filtros híbridos (Pre-filtering / Post-filtering de metadata). Armazene UUID de Tenants, Data de Criação e Tags junto ao vetor para fazer "Semantic Search limitada por Tenant_ID".
4. **RE-RANKING COMPULSÓRIO:** A primeira passada da busca vetorial (Ex: Cosine Similarity) recupera os Top-K (ex: 20) recortes. É OBRIGATÓRIO rodar um modelo de **Cross-Encoder / Reranker** (ex: Cohere Rerank, BGE Reranker) para reordenar os resultados precisos para enviar ao LLM, separando o sinal do ruído.
5. **PGVECTOR COMO START ABSOLUTO:** Em 90% das arquiteturas baseadas em PostgreSQL, adote a extensão `pgvector` antes de contratar bancos externos caros (Pinecone/Milvus). Mantenha Vetores na mesma transação atômica dos dados relacionais para evitar o pesadelo da "Distributed State Inconsistency" (ex: deletar no DB e esquecer de deletar no Pinecone). Escalonar para soluções dedicadas apenas acima de >10 Milhões de vetores.

## 🛑 Padrões (Certo vs Errado)

### Indexação (`pgvector` via SQL)

**❌ ERRADO** (Deixar sem índice ou usar índice ineficaz em coleções mutáveis):
```sql
-- Busca exata (K-NN) sem índice força um FULL TABLE SCAN de matemática em memória.
-- O banco cai ao passar de 100k linhas.
SELECT * FROM documents ORDER BY embedding <-> '[0.1, 0.2, ...]' LIMIT 5;
```

**✅ CERTO** (Criar um índice HNSW usando Cosine Distance):
```sql
-- Index HNSW entrega busca extremamente rápida (Approximate NN).
-- vector_cosine_ops especifica Similaridade por Coseno (<=>)
CREATE INDEX ON documents USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);

SELECT * FROM documents ORDER BY embedding <=> '[0.1, 0.2, ...]' LIMIT 5;
```

### Arquitetura de Chunking e Busca (TypeScript RAG)

**❌ ERRADO** (Extrair, vectorizar e buscar o documento como um todo / Sem Metadata Filtering):
```typescript
// Gerar embedding do documento inteiro de 10 páginas (15.000 tokens)
const emb = await openai.embeddings.create({ input: fullDocumentText });
await pinecone.upsert([{ id: "doc-1", values: emb.data[0].embedding }]);

// Buscar cruzando dados de múltiplos clientes (Acidental Data Leak!)
const results = await pinecone.query({ topK: 5, vector: queryEmbedding });
```

**✅ CERTO** (Semantic Chunking com Metadata Filtering para isolamento multi-tenant):
```typescript
// 1. Chunking do doc (ex: páginas de 500 tokens)
const chunks = recursiveCharacterTextSplitter(fullDocumentText);

// 2. Gravar com Tenant Isolation no metadata
const vectorsToUpsert = chunks.map((chunk, i) => ({
  id: `doc-1-chunk-${i}`,
  values: await getEmbedding(chunk),
  metadata: { tenant_id: "tenant-A", source: "doc-1", text: chunk }
}));
await pinecone.upsert(vectorsToUpsert);

// 3. Busca Híbrida: Busca Semântica LIMITADA pelo Escopo do Tenant
const results = await pinecone.query({
  topK: 15, // Puxa mais dados para o Rerank
  vector: queryEmbedding,
  filter: { tenant_id: "tenant-A" } // RLS / Pre-filtering no backend do Pinecone
});

// 4. Reranking (Cohere ou API similar) antes de mandar pro LLM
const finalTop3 = await rerankResults(userQuery, results);
```

## 🧠 Soluções do Mercado (Quando usar)
- `pgvector` (PostgreSQL): Aplicações que já usam PostgreSQL, garantindo integridade transacional ACID. Use indexes HNSW.
- `Pinecone`: Serverless cloud managed, ideal se não quer tratar DevOps. Performance líder em baixa latência.
- `Milvus` / `Qdrant`: Escala extrema corporativa em clusters (Bilhões de parâmetros).
- `Weaviate`: Combina muito bem buscas híbridas (Keyword BM25 + VETOR) nativamente (GraphQL + Nodes semânticos).

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

