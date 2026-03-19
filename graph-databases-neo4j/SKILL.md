---
name: Neo4j Graph Database & Cypher
description: Architect, query, and model graph databases using Neo4j and Cypher. Enforces relationship-centric data modeling, strict index usage, Cypher 25 patterns, and GraphRAG native integrations (VECTOR types).
---

# 🕸️ Neo4j Graph Architecture & Cypher Mastery

This skill defines the architectural dogmas and absolute best practices for building scalable relationship-driven applications, Recommendation Engines, and GraphRAG pipelines using **Neo4j** and **Cypher**.

## 🏛️ Graph Data Modeling Dogmas

In Neo4j, data modeling is entirely different from relational (SQL) or document (NoSQL) databases.

### 1. Specific Relationships over Generic Relationships
*   **Dogma:** Favor highly specific relationship types over generic relationship types with property filtering.
*   **Why:** Traversing a specific relationship type (e.g., `[:BOUGHT_PRODUCT]`) is an O(1) pointer hop. Filtering a generic relationship (e.g., `[:INTERACTED_WITH {type: 'bought'}]`) is an expensive O(N) property check.
*   **CERTO:** `(u:User)-[:RATED_5_STARS]->(m:Movie)`
*   **ERRADO:** `(u:User)-[:REVIEWED {rating: 5}]->(m:Movie)` (if you frequently query only 5-star ratings).

### 2. Nodes vs. Properties
*   **Rule:** If a property of an entity is shared across many nodes and acts as a central pivot for traversing or grouping data (e.g., "City", "Company", "Category"), promote it from a Node Property to its own Node Label.
*   **CERTO:** `(p:Person)-[:LIVES_IN]->(c:City {name: "London"})`
*   **ERRADO:** `(p:Person {city: "London"})` (if you need to find all people in London quickly).

## 🧮 Cypher Querying Excellence

### 1. Parameterized Queries (Mandatory)
*   **Dogma:** NEVER interpolate strings into Cypher queries. ALWAYS use parameters (`$param_name`).
*   **Why:** String interpolation prevents Neo4j from caching the query execution plan, destroying performance and opening the door to Cypher Injection.

```cypher
// CERTO
MATCH (u:User {id: $user_id})-[:FRIENDS_WITH]->(f:User)
RETURN f.name;

// ERRADO (Desempenho terrível e inseguro)
MATCH (u:User {id: '12345'})-[:FRIENDS_WITH]->(f:User)
```

### 2. Profile and Explain
*   **Rule:** Prefix complex queries with `PROFILE` or `EXPLAIN` during development to visualize the execution plan. Eliminate "NodeByLabelScan" operations on large datasets by ensuring proper Indexes exist.

### 3. APOC (Awesome Procedures on Cypher)
*   Leverage the APOC library for complex operations (batching huge updates, custom algorithms, data import/export), but do not use it for simple tasks that native Cypher can handle.

## 🧠 AI-Native Querying (Cypher 25+ & GraphRAG)

Neo4j is a foundational technology for advanced Retrieval-Augmented Generation (GraphRAG).

*   **VECTORS as First-Class Citizens:** Cypher 25 introduces the native `VECTOR` data type. Store LLM embeddings directly as properties on nodes.
*   **Hybrid Search:** Combine Vector Similarity Search with explicit Graph Traversal to ground LLMs in factual reality (e.g., "Find nodes textually similar to X, BUT ONLY IF they are connected to Category Y").
*   **`ai.*` Namespace:** Utilize Neo4j's native LLM integration namespace for embedding generation or semantic routing directly inside Cypher queries.

## 🚨 Anti-Patterns (DO NOT DO THIS)
*   ❌ **NEVER** execute unbounded queries like `MATCH (n)-[r]-(m) RETURN n, r, m` in production. Always anchor the pattern with a specific, indexed starting node.
*   ❌ **NEVER** use dense nodes (supernodes) without care. A node with millions of edges (e.g., a "User" node representing a famous celebrity followed by millions) will throttle traversal performance. Use Neo4j's specific optimizations for dense nodes or refactor the model.
*   ❌ **NEVER** use Neo4j when the workload is purely aggregate-heavy reporting (e.g., `SUM(revenue) GROUP BY month` across billions of records). Use a Columnar OLAP DB (ClickHouse, BigQuery) for that.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

