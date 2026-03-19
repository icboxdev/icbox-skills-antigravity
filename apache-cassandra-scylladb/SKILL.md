---
name: Apache Cassandra & ScyllaDB (Wide-Column)
description: Architect, model, and query highly scalable distributed wide-column stores like Cassandra and ScyllaDB. Enforces Query-First (application-driven) data modeling, aggressive denormalization, precise Partition Key selection, and time-series bucketing to avoid hot spots.
---

# 🐘 Apache Cassandra & ScyllaDB Mastery

This skill defines the architectural dogmas and absolute best practices for building massively scalable, zero-downtime, high-write-throughput distributed applications using **Apache Cassandra** or its high-performance C++ rewrite, **ScyllaDB**.

## 🏗️ Data Modeling Dogmas (Query-First Design)

In relational databases (SQL), you model the entities and then write queries. In Cassandra/ScyllaDB, you MUST do the exact opposite.

### 1. Query-Driven Modeling
*   **Dogma:** Design tables specifically to satisfy the reads your application performs. Identify the queries *first*, then build tables to answer those exact queries.
*   **Rule:** One query = One table (usually).

### 2. Aggressive Denormalization
*   **Dogma:** Data duplication is not just accepted; it is mandatory. 
*   **Why:** Cassandra does NOT support `JOIN` operations. If a query requires data from "Users" and "Departments", that data must be pre-joined (denormalized) into a single table at write time, or read via two separate async queries by the application logic.

## 🔑 The Primary Key Architecture

The Primary Key is the most critical design decision. It consists of two parts: `PRIMARY KEY ((Partition_Key), Clustering_Column_1, Clustering_Column_2)`.

### 1. The Partition Key (Data Distribution)
*   **Dogma:** The Partition Key dictates which physical node in the cluster holds the data. 
*   **Rule:** A good Partition Key MUST have high cardinality (many unique values) and ensure an even distribution of data.
*   **Anti-Pattern:** Using something like `country_code` as a partition key. The node holding "US" or "BR" will become a massive hotspot, while the node holding "AQ" (Antarctica) will sit idle.

### 2. Clustering Columns (Sorting within Partition)
*   **Dogma:** Clustering columns dictate the on-disk sorting order of rows *inside* a single partition.
*   **Rule:** Use clustering columns to answer range queries (`>, <, >=, <=`) or generic `ORDER BY` operations, because Cassandra can ONLY perform these operations within a single partition.

## ⏳ Time-Series & High Write Volume

Cassandra/ScyllaDB excels at time-series data (logs, IoT metrics), but requires careful partition management.

### 1. Partition Bucketing
*   **Dogma:** NEVER allow a partition to grow infinitely (e.g., partitioning IoT sensor data solely by `sensor_id`).
*   **Rule:** Append a time bucket to the partition key to split the data into manageable chunks.
    *   **CERTO:** `PRIMARY KEY ((sensor_id, month_year), recorded_at)`
    *   **ERRADO:** `PRIMARY KEY ((sensor_id), recorded_at)` -> The partition for `sensor_1` will hit the 100MB+ limit and degrade cluster performance.

### 2. Compaction Strategy
*   **Rule:** For Time-Series Append-Only workloads, ALWAYS use **Time Window Compaction Strategy (TWCS)**. Do not use the default Size Tiered Compaction Strategy (STCS) for time-series, as it will cause write amplification and tombstone issues.

## 🚨 Anti-Patterns (DO NOT DO THIS)

*   ❌ **NEVER** read across multiple partitions (`SELECT * FROM table WHERE clustering_col = 'x' ALLOW FILTERING`). This forces a full cluster scan and will crash production. Queries MUST include the partition key (`WHERE partition_key = 'y'`).
*   ❌ **NEVER** use Secondary Indexes (2i) to model relationships. They scale terribly. If you need to query by another field, create a new denormalized table or use Storage-Attached Indexing (SAI).
*   ❌ **NEVER** treat Cassandra like a queue (frequent inserts followed by frequent deletes). Deletes in Cassandra create "Tombstones" (invisible markers). A query scanning over thousands of tombstones will time out. Use TTL (Time To Live) for expiring data instead of explicit `DELETE` statements.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

