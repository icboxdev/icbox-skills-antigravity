---
name: Elasticsearch & OpenSearch (Analytics & Search)
description: Architect, scale, and optimize Elasticsearch or OpenSearch clusters. Enforces structured logging (ECS), Index Lifecycle Management (ILM), dedicated ingestion layers (Kafka/Logstash), flat index structures, and Vector Search for RAG.
---

# 🔎 Elasticsearch & OpenSearch Architecture Mastery

This skill defines the absolute best practices for building scalable Log Analytics, Full-Text Search, and Vector Search platforms using **Elasticsearch** or **OpenSearch**.

## 🏗️ Architectural Dogmas

### 1. The Ingestion Buffer (Never Ingest Directly)
*   **Dogma:** NEVER expose the Elasticsearch/OpenSearch cluster directly to raw high-throughput log producers (e.g., application servers).
*   **Rule:** ALWAYS place a dedicated ingestion layer (Kafka, Logstash, Fluentd, or Fluent Bit) in front of the cluster. This layer handles buffering during cluster spikes, enrichment, deduplication, and flattening.

### 2. Flat Structures > Nested Objects
*   **Dogma:** Flatten data structures at ingest time. Avoid deeply nested objects unless independent querying of nested elements is strictly required for the business logic.
*   **Rule:** Flat JSON structures are significantly faster to query and index. Mapping conflicts are reduced.
*   **Anti-Pattern:** Emulating Relational Joins. Elasticsearch is denormalized by nature. Do application-side joins or denormalize at ingest.

### 3. Schema & Mapping Consistency
*   **Dogma:** Adopt a common schema, such as the **Elastic Common Schema (ECS)**, for all log ingestion.
*   **Rule:** Use Index Templates to dynamically apply mappings to new daily/hourly log indices. Ensure string fields used for exact filtering are mapped as `keyword`, and text for full-text search as `text`.

## ⚙️ Cluster Scale & Lifecycle

### 1. Index Lifecycle Management (ILM) / Data Lifecycle Management (DLM)
Log analytics clusters MUST implement a tiering strategy to control costs and RAM usage.
*   **Hot Tier:** Active indexing, SSDs, fast CPUs. Retention: ~7-14 days.
*   **Warm/Ultra-Warm Tier:** Read-only data, slower disks, optimized for querying.
*   **Cold/Frozen Tier:** Historic data stored in Object Storage (S3/GCS/Azure Blob) leveraging features like Searchable Snapshots.

### 2. Sharding Strategy
*   **Dogma:** DO NOT over-shard. Having thousands of tiny shards exhausts the cluster master node's heap memory.
*   **Rule:** Aim for shard sizes between **10GB to 50GB**. Use rollover policies based on size, not exclusively on time (e.g., rollover when index > 50GB or > 30 days).

## 🧠 AI & Vector Search (2024-2025 Patterns)
Elasticsearch and OpenSearch are now first-class Vector Databases.
*   **Vector Embeddings:** Utilize native `dense_vector` or `knn_vector` field mapping types.
*   **Hybrid Search:** Combine lexical scoring (BM25) via `match` queries with semantic scoring (kNN vector search) via the `rrf` (Reciprocal Rank Fusion) algorithm for the highest possible relevance in Search implementations.

## 🚨 Anti-Patterns (DO NOT DO THIS)
*   ❌ **NEVER** use `wildcard` queries on `text` fields if performance matters. Use NGrams at index time instead.
*   ❌ **NEVER** run heavy aggregations on high-cardinality `text` fields. Ensure fields targeted by `terms` aggregations are mapped as `keyword`.
*   ❌ **NEVER** ignore the cluster health. If it drops to `yellow` (missing replicas) or `red` (missing primary shards), investigate immediately before writing more data.
