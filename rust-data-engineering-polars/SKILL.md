---
name: Data Engineering em Rust (Polars)
description: Architect, scale, and optimize extreme high-performance data processing pipelines in Rust replacing Python/Pandas via the Polars crate. Enforces LazyFrame evaluation, memory safety, and Rayon multi-threading.
---

# Data Engineering Extreme (Rust / Polars)

Para analítica de Big Data em memória (ETL local, Dashboards de BI IoT, Series Temporais Críticas), abrimos mão do Python (Pandas) pela crate `polars`. O Polars baseia-se em Apache Arrow provendo uma eficiência multithreaded brutal sem a Global Interpreter Lock (GIL) imposta por Python.

## Arquitetura & Dogmas OBRIGATÓRIOS

- **Use `LazyFrame`**: NUNCA carregue dados gigantes e filtre usando `.filter()` em um `DataFrame` eagenly (ansiosamente). SEMPRE inicie a operação em lazy evaluation e só concretize as alocações ao chamar `.collect()`. Isso permite que o Query Engine do Polars aplique *predicate pushdown*, otimizando a leitura antes dela acontecer (Ex: lendo arquivos Parquet parciais por coluna).
- **Sem Copies Desnecessários**: Trabalhe em colunas de Referência O(1) sempre que mutando Df.
- **Parquet sobre CSV**: Ao instanciar jobs em nuvem (S3 / R2), sempre busque o formato colunar Parquet pelo tamanho comprimido. O IOps (Disco) ditará a morte da performance em CSV se não particionado.
- **Evitar Row Iteration**: Loops iterativos (for `row` in) matam a SIMD vectorization. Use ESTRITAMENTE a API de Contextos/Expression de colunas do Polars (`col("x").sum()`, `.alias()`), nunca lide com dados por linha na mão.

## Few-Shot: Avaliação Preguiçosa Otimizada (Predicate Pushdown)

Se a source tiver 100 milhões de linhas de Sensores IoT, com LazyFrame, filtraremos os dados ainda na leitura de Disco.

### 🟢 CORRETO
```rust
use polars::prelude::*;

fn aggregate_factory_sensors(filepath: &str) -> PolarsResult<DataFrame> {
    // 1. Lazy evaluation: NADA FOI LIDO para a Memória ainda.
    let lazy_df = LazyCsvReader::new(filepath)
        .with_has_header(true)
        .finish()?;

    // 2. Query Builder: O engine vai ignorar colunas inativas
    // e ler as linhas restritas diretamente no IO usando Pushdown!
    let output = lazy_df
        .filter(col("status").eq(lit("CRITICAL")))
        .with_column((col("temperature") * lit(1.8) + lit(32.0)).alias("temp_fahrenheit"))
        .group_by([col("machine_id")])
        .agg([
            col("temp_fahrenheit").mean().alias("avg_temp_f"),
            col("event_timestamp").max().alias("last_event")
        ])
        .sort("avg_temp_f", Default::default()) // default: asc
        .collect()?; // 3. ONLY HERE THE EXECUTION TRIGGERS AND MEMORY IS ALLOCATED

    Ok(output)
}
```

### 🔴 ERRADO
```rust
use polars::prelude::*;

fn bad_aggregate_sensors(filepath: &str) -> PolarsResult<DataFrame> {
    // 🚨 ANTI-PATTERN: Eagerly carrega os 100 MI Rows de todas colunas na RAM
    let mut df = CsvReader::from_path(filepath)?.has_header(true).finish()?;

    // 🚨 Aloca cópias ineficientes para cada filtro intermediário!
    let mask = df.column("status")?.equal("CRITICAL")?;
    let df = df.filter(&mask)?;

    // 🚨 A agregação rodará sob uma montanha de memória lida a toa
    Ok(df) // PANIC via OOMKilled se arquivo > Memória RAM Disp.
}
```

## Few-Shot: Window Functions (Séries Temporais)

Para calcular médias móveis do Chão de Fábrica, O Polars lida brilhantemente como se fosse o SQL avançado de Window.

### 🟢 CORRETO
```rust
use polars::prelude::*;

fn rolling_iot_average(df: LazyFrame) -> PolarsResult<DataFrame> {
    let q = df.with_column(
            col("temperature")
            .rolling_mean(RollingOptions {
                window_size: Duration::parse("15m"),
                min_periods: 1,
                ..Default::default()
            })
            .over([col("sensor_id")])
            .alias("rolling_15m_avg")
        )
        .collect()?;
    Ok(q)
}
```

## Dependências e Relevamento Arquitetural Multithread
A crate Rayon atua sorrateiramente por sob o Polars em Rust. Como tal, os workers em um backend assíncrono Tokio podem conflitar com o Rayon worker threadpool se mal calibrados. Ao construir rotas `axum` que disparem agregações gigantes em Polars:
- SEMPRE envolva a rotina pesada (.collect()) num `tokio::task::spawn_blocking(move || { ... })`.
- Falhar nisto irá bloquear as threads exclusivas do Tokio, tirando o site (HTTP) offline enquanto os números do Rayon processam ("Event loop Starvation").
