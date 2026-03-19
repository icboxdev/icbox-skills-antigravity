---
name: Cloud Data Warehouses & Analytics
description: Architect, scale, and optimize Cloud Data Warehouses (Snowflake, BigQuery, Databricks) enforcing ELT pipelines, Medallion Architecture (Bronze/Silver/Gold), and Columnar OLAP strategies.
---

# Cloud Data Warehouses & Analytics

Para cargas de trabalho analíticas (OLAP), bancos relacionais tradicionais (PostgreSQL/MySQL - OLTP) colapsam ou ficam caros demais. A fronteira 2024 exige separação entre Compute e Storage e uso agressivo da Arquitetura Medallion.

## 🏛️ Dogmas de Arquitetura Data Warehouse (DWH)

1. **PROIBA TENTATIVAS DE OLAP EM SQL OLTP:** NUNCA force um PostgreSQL/MySQL de produção a rodar `GROUP BY` e Aggregations massivos sobre dezenas de milhões de linhas para popular Dashboards. Utilize processos de ETL/ELT para enviar os dados para um DWH Columnar (BigQuery/Snowflake) e leia o Dashboard de lá.
2. **USE O PADRÃO ELT, NÃO ETL:** A nuvem inverteu a lógica. Não transforme os dados ANTES de inserir (ETL server). Extraia os dados crus dos bancos de origem (Fivetran/Airbyte) e **Faça o Load do dado cru** no Data Warehouse. Faça a Transformação (Transform) DENTRO do DWH utilizando dbt (data build tool) aproveitando a força massiva do engine columnar.
3. **IMPONHA ARQUITETURA MEDALLION:** Pipeline de dados OBRIGATÓRIA em 3 camadas lógicas:
   - **BRONZE (Raw):** Dados puros anexados assim que chegam, com histórico completo e imutável (Append-only). Sem filtro.
   - **SILVER (Cleansed):** Dados limpos, deduplicados, tipados e enriquecidos. Onde regras de integridade e Data Quality atuam.
   - **GOLD (Business):** Agregações hiper-otimizadas prontas para consumo humano (Star Schema/Dimensional Models) para BI e Dashboards.
4. **OTIMIZE STORAGE COLUNAR (Parquet/ORC):** DWHs (Snowflake, BigQuery) cobram por DADOS ESCANEADOS. Se você fizer `SELECT *` numa tabela colunar de Terabytes, você causará um desastre financeiro. OBRIGATÓRIO selecionar EXCLUSIVAMENTE as colunas necessárias para o dashboard.
5. **PARTICIONAMENTO E CLUSTERING (Z-ORDER):** Tabelas fact (fatos) com crescimento infinito DEVEM ser particionadas pela data/tempo, e "clustered" (organizadas fisicamente) por chaves de filtro comum (Ex: `tenant_id`) para induzir o "Partition Pruning" (Evitar que a query leia arquivos irrelevantes no S3/GCS).

## 🛑 Padrões (Certo vs Errado)

### Custos de Queries no BigQuery / Snowflake

**❌ ERRADO** (Anti-Pattern Mortal em BigQuery - Custa milhares de dólares):
```sql
-- Em DWH Colunar, isso escaneia a TABELA INTEIRA em todos os discos. 
-- Nunca permita SELECT * em Cloud DWHs a menos que seja estritamente validado.
SELECT * FROM sales_raw_data_2020_to_2024;
```

**✅ CERTO** (Partition Pruning e Columnar Selection):
```sql
-- Seleciona APENAS as 2 colunas necessárias (corta scan em 90%)
-- E OBRIGA o uso do partition filter (corta scan pros outros 4 anos)
SELECT store_id, SUM(total_amount) 
FROM sales_raw_data
WHERE date_shipped >= '2024-01-01' AND date_shipped <= '2024-01-31'
GROUP BY store_id;
```

### Transformações dbt (Medallion Pattern)

**❌ ERRADO** (Fazer ETL cru Python num cronjob batendo no DB de produção):
```python
# Executar queries pesadas contra o PostgreSQL de prod para gerar um CSV 
# e fazer upload... Causa lock no DB e lentidão pros usuários.
df = pd.read_sql("SELECT ... complex JOINs ... FROM master", pg_conn)
```

**✅ CERTO** (ELT via dbt Cloud):
1. **Fivetran/Airbyte:** Extrai e faz "Log-based CDC" dos dados do Postgres enviando direto pra camada Bronze do Snowflake.
2. **dbt (SQL):** Roda job noturno DENTRO do Snowflake transformando Bronze -> Silver -> Gold.

## 🧠 Guia Rápido de Soluções
- `BigQuery (GCP)`: Expetacular para Data Lakes serverless, precificação majoritariamente "On-Demand" (Por TB lido). Ideal onde não há equipe de Big Data dedicada.
- `Snowflake`: Agnostico. Separa Storage e Compute brilhantemente usando "Virtual Warehouses". Ideal para data-sharing B2B e multi-cloud.
- `Databricks`: Unifica Ciência de Dados (Spark/Python) e SQL Analytics ("Lakehouse"). Melhor para equipes pautadas em Engenharia de Machine Learning massiva.
