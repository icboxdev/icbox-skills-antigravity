---
name: Report Builder Engineering (React + Rust)
description: Architect, generate, validate, and optimize report builder platforms using React frontend and Rust backend. Covers server-side PDF generation (Typst, Tera, genpdf, headless Chromium), file import/export (CSV, XLSX, Parquet via calamine/Polars), report template designer, data-driven layouts, scheduled report delivery, multi-tenant isolation, and production-grade performance patterns.
---

# Report Builder Engineering (React + Rust) — Diretrizes Senior+

## 0. Princípio Fundamental: Relatório é Comunicação

Um relatório não é dump de dados — é uma **comunicação estruturada para decisão**:
- Todo relatório DEVE ter: título, período, audiência, e conclusão/ação sugerida.
- Relatório sem contexto = planilha glorificada. Reprove-o.
- PDF é output final — o relatório é definido por um **template** + **dados** + **filtros**.

> ⚠️ **Crime Arquitetural**: Gerar PDF montando string HTML manualmente no backend. SEMPRE use um template engine tipado (Tera/Typst) com dados estruturados.

---

## 1. Arquitetura de Report Builder (React + Rust)

### 1.1 Fluxo Completo

```
[React Frontend]                        [Rust Backend (Axum)]
     │                                       │
     ├─ Report Designer (drag-drop)          │
     │   → Template JSON (layout + bindings) │
     │                                       │
     ├─ Report Viewer (preview)              │
     │   → Renderiza HTML no client          │
     │                                       │
     ├─ Export Request ──────────────────────►│
     │   POST /reports/:id/export            │
     │   { format: "pdf", filters: {...} }   │
     │                                       ├─ 1. Busca template do DB
     │                                       ├─ 2. Busca dados (SQLx query)
     │                                       ├─ 3. Renderiza HTML (Tera) ou Typst
     │                                       ├─ 4. Gera PDF (Typst/headless Chrome)
     │                                       ├─ 5. Salva no Object Storage (S3)
     │◄──── 6. Retorna URL assinada ─────────┤
     │                                       │
     ├─ Import File ────────────────────────►│
     │   POST /imports/upload                │
     │   multipart/form-data                 │
     │                                       ├─ 1. Valida tipo/tamanho
     │                                       ├─ 2. Parse (calamine/csv/polars)
     │                                       ├─ 3. Valida schema + dados
     │                                       ├─ 4. Transforma e persiste
     │◄──── 5. Retorna resultado ────────────┤
```

### 1.2 Separação de Responsabilidades

| Camada | Responsabilidade | Stack |
|---|---|---|
| **Frontend** | Design de template, preview, filtros, request de export | React + TypeScript |
| **API** | Autenticação, validação, orquestração, queue de jobs | Axum + SQLx |
| **Template Engine** | Renderização de HTML/Typst a partir de dados | Tera ou Typst |
| **PDF Generator** | Geração do arquivo PDF final | Typst (puro) ou headless Chromium |
| **File Parser** | Import de CSV/XLSX/Parquet, validação, transformação | calamine + csv + Polars |
| **Storage** | Armazenamento de PDFs gerados e arquivos importados | S3-compatible (MinIO) |
| **Job Queue** | Processamento assíncrono de relatórios pesados | Tokio tasks ou Redis queue |

---

## 2. PDF Generation em Rust — Estratégias

### 2.1 Decisão de Abordagem

| Abordagem | Quando Usar | Trade-off |
|---|---|---|
| **Typst (puro Rust)** | Relatórios programáticos, alto volume, serverless | Melhor performance, sem deps externas. Markup próprio (não HTML). |
| **Tera + headless Chromium** | Templates HTML/CSS complexos, fidelidade visual pixel-perfect | Mais flexível em layout, mas requer Chromium em runtime. |
| **genpdf/printpdf** | Documentos simples (recibos, notas fiscais) | API de baixo nível, posicionamento manual. |

**Dogma**: Para novo projeto, use **Typst** como padrão. Headless Chromium apenas quando CSS complexo (grid, flexbox, media queries) é requisito inegociável.

### 2.2 Typst — Geração Nativa em Rust

```rust
// CERTO: Typst como library Rust — geração de PDF sem deps externas
use typst::compile;
use typst::model::Document;

// Template Typst armazenado no banco ou filesystem
const INVOICE_TEMPLATE: &str = r#"
#set page(paper: "a4", margin: 2cm)
#set text(font: "Inter", size: 10pt)

#align(center)[
  #text(size: 18pt, weight: "bold")[{{ company_name }}]
  #v(4pt)
  #text(size: 10pt, fill: gray)[Relatório de Vendas — {{ period }}]
]

#v(1cm)

#table(
  columns: (auto, 1fr, auto, auto),
  inset: 8pt,
  fill: (_, row) => if row == 0 { rgb("#1a1a2e") } else if calc.odd(row) { rgb("#f8f8f8") } else { white },
  text(fill: white, weight: "bold")[Produto],
  text(fill: white, weight: "bold")[Categoria],
  text(fill: white, weight: "bold")[Qtde],
  text(fill: white, weight: "bold")[Receita],
  {{ #each items }}
  [{{ name }}], [{{ category }}], [{{ quantity }}], [R$ {{ revenue }}],
  {{ /each }}
)

#v(1cm)
#line(length: 100%, stroke: 0.5pt + gray)
#v(4pt)
#align(right)[
  *Total:* R$ {{ total_revenue }}
]
"#;

/// Gera PDF usando Typst como library
async fn generate_pdf_typst(
    template: &str,
    data: &ReportData,
) -> Result<Vec<u8>, ReportError> {
    // 1. Renderiza o template com dados (usando Tera para interpolação)
    let tera = tera::Tera::default();
    let mut ctx = tera::Context::new();
    ctx.insert("company_name", &data.company_name);
    ctx.insert("period", &data.period);
    ctx.insert("items", &data.items);
    ctx.insert("total_revenue", &data.total_revenue);
    let rendered = tera.render_str(template, &ctx)?;

    // 2. Compila Typst → PDF (CPU-bound, usar spawn_blocking)
    let pdf_bytes = tokio::task::spawn_blocking(move || {
        typst_compile_to_pdf(&rendered)
    }).await??;

    Ok(pdf_bytes)
}

// ERRADO: gerar PDF montando string HTML manualmente
fn bad_generate_pdf(data: &Data) -> String {
    format!("<html><body><h1>{}</h1><table>{}</table></body></html>",
        data.title,
        data.rows.iter().map(|r| format!("<tr><td>{}</td></tr>", r.name)).collect::<String>()
    ) // HTML frágil, sem template engine, sem escape — XSS possível
}
```

### 2.3 Tera + Headless Chromium — Layout Complexo

```rust
// CERTO: Tera template + headless Chromium para CSS complex layouts
use tera::{Tera, Context};
use headless_chrome::{Browser, LaunchOptions};

/// Templates Tera organizados em diretório
fn init_templates() -> Tera {
    let mut tera = Tera::new("templates/reports/**/*.html")
        .expect("Failed to parse report templates");
    // Registrar filtros customizados
    tera.register_filter("currency_brl", currency_brl_filter);
    tera.register_filter("date_br", date_br_filter);
    tera
}

/// Gera PDF via headless Chromium (para templates HTML/CSS complexos)
async fn generate_pdf_chromium(
    tera: &Tera,
    template_name: &str,
    data: &ReportData,
) -> Result<Vec<u8>, ReportError> {
    // 1. Renderiza HTML com Tera
    let mut ctx = Context::new();
    ctx.insert("report", data);
    ctx.insert("generated_at", &chrono::Utc::now().to_rfc3339());
    let html = tera.render(template_name, &ctx)?;

    // 2. Gera PDF via headless Chromium (CPU-bound)
    let pdf_bytes = tokio::task::spawn_blocking(move || {
        let browser = Browser::new(LaunchOptions {
            headless: true,
            args: vec![
                "--no-sandbox",              // necessário em containers
                "--disable-dev-shm-usage",   // evita crash por memória compartilhada
                "--disable-gpu",             // não precisamos de GPU para PDF
            ].into_iter().map(|s| s.into()).collect(),
            ..Default::default()
        })?;

        let tab = browser.new_tab()?;

        // Salvar HTML em arquivo temporário (evita problemas com HTML grande > 100MB)
        let tmp_path = format!("/tmp/report-{}.html", uuid::Uuid::new_v4());
        std::fs::write(&tmp_path, &html)?;
        tab.navigate_to(&format!("file://{}", tmp_path))?;
        tab.wait_until_navigated()?;

        let pdf = tab.print_to_pdf(Some(headless_chrome::protocol::cdp::Page::PrintToPdfParams {
            landscape: Some(false),
            display_header_footer: Some(true),
            header_template: Some(HEADER_TEMPLATE.into()),   // header/footer via template
            footer_template: Some(FOOTER_TEMPLATE.into()),
            margin_top: Some(1.5),       // cm
            margin_bottom: Some(1.5),
            margin_left: Some(1.0),
            margin_right: Some(1.0),
            paper_width: Some(8.27),     // A4
            paper_height: Some(11.69),
            prefer_css_page_size: Some(true),
            ..Default::default()
        }))?;

        // Cleanup
        std::fs::remove_file(&tmp_path).ok();

        Ok::<Vec<u8>, ReportError>(pdf)
    }).await??;

    Ok(pdf_bytes)
}

// Header/Footer templates para headless Chrome
const HEADER_TEMPLATE: &str = r#"
<div style="font-size:8px; width:100%; text-align:center; color:#888;">
    <span class="title"></span>
</div>
"#;

const FOOTER_TEMPLATE: &str = r#"
<div style="font-size:8px; width:100%; display:flex; justify-content:space-between; padding:0 24px; color:#888;">
    <span>Gerado em <span class="date"></span></span>
    <span>Página <span class="pageNumber"></span> de <span class="totalPages"></span></span>
</div>
"#;
```

### 2.4 Tera Template — Padrão para Relatórios HTML

```html
{# templates/reports/sales_report.html #}
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <style>
    @page {
      size: A4;
      margin: 1.5cm 1cm;
    }

    body {
      font-family: 'Inter', sans-serif;
      font-size: 10pt;
      color: #1a1a2e;
      line-height: 1.4;
    }

    .report-header {
      text-align: center;
      margin-bottom: 24px;
      padding-bottom: 16px;
      border-bottom: 2px solid #1a1a2e;
    }

    .kpi-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 12px;
      margin-bottom: 24px;
    }

    .kpi-card {
      border: 1px solid #e5e5e5;
      border-radius: 8px;
      padding: 12px;
      text-align: center;
    }

    .kpi-value {
      font-size: 20pt;
      font-weight: 700;
      color: #1a1a2e;
    }

    .data-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 16px;
    }

    .data-table th {
      background: #1a1a2e;
      color: white;
      padding: 8px 12px;
      text-align: left;
      font-size: 9pt;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .data-table td {
      padding: 6px 12px;
      border-bottom: 1px solid #eee;
      font-size: 9pt;
    }

    .data-table tr:nth-child(even) { background: #f8f8fa; }
    .data-table .numeric { text-align: right; font-variant-numeric: tabular-nums; }

    /* Page break control — ESSENCIAL para relatórios multi-página */
    .page-break { page-break-before: always; }
    .no-break { page-break-inside: avoid; }
  </style>
</head>
<body>
  <div class="report-header">
    <h1>{{ report.title }}</h1>
    <p>Período: {{ report.date_start | date_br }} — {{ report.date_end | date_br }}</p>
    <p style="color: #888; font-size: 8pt;">Gerado em {{ generated_at | date_br }}</p>
  </div>

  {# KPI Cards #}
  <div class="kpi-grid">
    {% for kpi in report.kpis %}
    <div class="kpi-card no-break">
      <div style="font-size: 8pt; color: #888; text-transform: uppercase;">{{ kpi.label }}</div>
      <div class="kpi-value">{{ kpi.value | currency_brl }}</div>
      <div style="font-size: 8pt; color: {% if kpi.change > 0 %}#10b981{% else %}#ef4444{% endif %};">
        {% if kpi.change > 0 %}↑{% else %}↓{% endif %} {{ kpi.change | abs }}%
      </div>
    </div>
    {% endfor %}
  </div>

  {# Data Table #}
  <table class="data-table">
    <thead>
      <tr>
        {% for col in report.columns %}
        <th class="{% if col.numeric %}numeric{% endif %}">{{ col.label }}</th>
        {% endfor %}
      </tr>
    </thead>
    <tbody>
      {% for row in report.rows %}
      <tr>
        {% for col in report.columns %}
        <td class="{% if col.numeric %}numeric{% endif %}">
          {% if col.format == "currency" %}
            {{ row[col.key] | currency_brl }}
          {% elif col.format == "date" %}
            {{ row[col.key] | date_br }}
          {% else %}
            {{ row[col.key] }}
          {% endif %}
        </td>
        {% endfor %}
      </tr>
      {% endfor %}
    </tbody>
  </table>

  {# Totais #}
  <div class="no-break" style="margin-top: 16px; text-align: right; font-weight: 700;">
    Total: {{ report.total | currency_brl }}
  </div>
</body>
</html>
```

---

## 3. File Import — Parsing Avançado em Rust

### 3.1 Arquitetura de Import Pipeline

```
[Upload multipart] → [Validate] → [Parse] → [Transform] → [Validate Data] → [Persist]
                        │             │            │              │
                   tipo + size    headers     mapping de    schema check
                   mime check     detect      colunas       constraints
                   virus scan    encoding                   data types
```

### 3.2 Import Handler — Axum

```rust
// CERTO: import handler com validação em camadas, async file processing
use axum::{extract::Multipart, Json};
use calamine::{Reader, Xlsx, DataType};
use csv::ReaderBuilder;

/// Formatos suportados
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
enum ImportFormat {
    Csv,
    Xlsx,
    Parquet,
}

/// Resultado do import com detalhes de validação
#[derive(Debug, Serialize)]
struct ImportResult {
    total_rows: usize,
    imported_rows: usize,
    skipped_rows: usize,
    errors: Vec<ImportError>,
    warnings: Vec<ImportWarning>,
}

/// Upload handler — validação em camadas
async fn handle_import(
    State(state): State<AppState>,
    tenant: TenantContext,
    mut multipart: Multipart,
) -> Result<Json<ImportResult>, ApiError> {
    // 1. Extrair arquivo
    let field = multipart.next_field().await?
        .ok_or(ApiError::validation("Nenhum arquivo enviado"))?;

    let filename = field.file_name()
        .ok_or(ApiError::validation("Filename ausente"))?
        .to_string();
    let content_type = field.content_type().map(|s| s.to_string());
    let data = field.bytes().await?;

    // 2. Validar tamanho (max 50MB)
    const MAX_FILE_SIZE: usize = 50 * 1024 * 1024;
    if data.len() > MAX_FILE_SIZE {
        return Err(ApiError::validation(&format!(
            "Arquivo excede limite de {}MB", MAX_FILE_SIZE / 1024 / 1024
        )));
    }

    // 3. Detectar formato
    let format = detect_format(&filename, content_type.as_deref())?;

    // 4. Parse em spawn_blocking (CPU-bound)
    let parsed = tokio::task::spawn_blocking(move || {
        parse_file(&data, &format)
    }).await??;

    // 5. Validar schema e dados
    let validated = validate_import_data(&parsed, &tenant)?;

    // 6. Persistir
    let result = persist_import(&state.db, &tenant, validated).await?;

    Ok(Json(result))
}

/// Detectar formato pelo nome e content-type
fn detect_format(filename: &str, content_type: Option<&str>) -> Result<ImportFormat, ApiError> {
    let ext = filename.rsplit('.').next().unwrap_or("").to_lowercase();
    match ext.as_str() {
        "csv" | "tsv" => Ok(ImportFormat::Csv),
        "xlsx" | "xls" => Ok(ImportFormat::Xlsx),
        "parquet" => Ok(ImportFormat::Parquet),
        _ => Err(ApiError::validation(&format!(
            "Formato '{}' não suportado. Use: csv, xlsx, parquet", ext
        ))),
    }
}

// ERRADO: aceitar qualquer formato sem validação
fn bad_import(data: Vec<u8>) -> Result<(), Error> {
    let text = String::from_utf8(data)?;  // crash em binário (xlsx)
    // sem validação de tamanho, tipo, encoding...
    Ok(())
}
```

### 3.3 Parsers por Formato

```rust
// CERTO: CSV parser com detecção de encoding e delimiter
fn parse_csv(data: &[u8]) -> Result<ParsedData, ImportError> {
    // Detectar encoding (UTF-8, Latin-1, etc.)
    let (decoded, _encoding, had_errors) = encoding_rs::UTF_8.decode(data);
    if had_errors {
        // Fallback para Latin-1 (comum em exports do Excel BR)
        let (decoded_latin, _, _) = encoding_rs::WINDOWS_1252.decode(data);
        return parse_csv_string(&decoded_latin);
    }
    parse_csv_string(&decoded)
}

fn parse_csv_string(content: &str) -> Result<ParsedData, ImportError> {
    // Detectar delimiter (vírgula, ponto-e-vírgula, tab)
    let delimiter = detect_delimiter(content);

    let mut reader = ReaderBuilder::new()
        .delimiter(delimiter)
        .has_headers(true)
        .flexible(true)          // aceitar linhas com colunas a mais/menos
        .trim(csv::Trim::All)    // trim whitespace
        .from_reader(content.as_bytes());

    let headers: Vec<String> = reader.headers()?.iter().map(|h| h.to_string()).collect();
    let mut rows = Vec::new();
    let mut errors = Vec::new();

    for (idx, record) in reader.records().enumerate() {
        match record {
            Ok(row) => rows.push(row.iter().map(|f| f.to_string()).collect()),
            Err(e) => errors.push(ImportError::row(idx + 2, &e.to_string())),
        }
    }

    Ok(ParsedData { headers, rows, errors })
}

// CERTO: XLSX parser com calamine — lê todas as sheets
fn parse_xlsx(data: &[u8]) -> Result<ParsedData, ImportError> {
    let cursor = std::io::Cursor::new(data);
    let mut workbook: Xlsx<_> = calamine::open_workbook_from_rs(cursor)
        .map_err(|e| ImportError::parse(&format!("Arquivo XLSX inválido: {}", e)))?;

    // Usar primeira sheet por padrão
    let sheet_names = workbook.sheet_names().to_vec();
    let sheet_name = sheet_names.first()
        .ok_or(ImportError::parse("XLSX sem sheets"))?;

    let range = workbook.worksheet_range(sheet_name)
        .ok_or(ImportError::parse(&format!("Sheet '{}' vazia", sheet_name)))??;

    let mut rows_iter = range.rows();

    // Headers = primeira linha
    let headers: Vec<String> = rows_iter.next()
        .ok_or(ImportError::parse("Sheet sem dados"))?
        .iter()
        .map(|cell| cell_to_string(cell))
        .collect();

    // Dados
    let rows: Vec<Vec<String>> = rows_iter
        .map(|row| row.iter().map(|cell| cell_to_string(cell)).collect())
        .collect();

    Ok(ParsedData { headers, rows, errors: vec![] })
}

/// Converter cell do calamine para String com formatação correta
fn cell_to_string(cell: &DataType) -> String {
    match cell {
        DataType::Int(i) => i.to_string(),
        DataType::Float(f) => {
            // Evitar "1.0" para inteiros, "1234.56" para decimais
            if f.fract() == 0.0 { format!("{:.0}", f) }
            else { format!("{:.2}", f) }
        }
        DataType::String(s) => s.trim().to_string(),
        DataType::Bool(b) => b.to_string(),
        DataType::DateTime(d) => {
            // calamine retorna datetime como float (dias desde 1900-01-01)
            excel_date_to_iso(*d).unwrap_or_default()
        }
        DataType::Empty => String::new(),
        DataType::Error(e) => format!("#ERROR: {:?}", e),
        _ => String::new(),
    }
}

// CERTO: Parquet com Polars — performático para grandes volumes
fn parse_parquet(data: &[u8]) -> Result<ParsedData, ImportError> {
    let cursor = std::io::Cursor::new(data);
    let df = polars::prelude::ParquetReader::new(cursor)
        .finish()
        .map_err(|e| ImportError::parse(&format!("Parquet inválido: {}", e)))?;

    let headers: Vec<String> = df.get_column_names()
        .iter().map(|s| s.to_string()).collect();

    let rows: Vec<Vec<String>> = (0..df.height())
        .map(|i| {
            df.get_columns().iter()
                .map(|col| format!("{}", col.get(i).unwrap_or(polars::prelude::AnyValue::Null)))
                .collect()
        })
        .collect();

    Ok(ParsedData { headers, rows, errors: vec![] })
}
```

### 3.4 Validação de Dados Importados

```rust
// CERTO: validação com schema definition e regras de negócio
#[derive(Debug, Clone)]
struct ImportSchema {
    columns: Vec<ColumnDef>,
    required_columns: Vec<String>,
    max_rows: usize,
}

#[derive(Debug, Clone)]
struct ColumnDef {
    name: String,
    aliases: Vec<String>,        // "nome", "name", "Nome Completo" → mapeiam para "name"
    data_type: ColumnType,
    required: bool,
    max_length: Option<usize>,
    validation: Option<Box<dyn Fn(&str) -> bool + Send + Sync>>,
}

#[derive(Debug, Clone)]
enum ColumnType {
    Text,
    Integer,
    Decimal,
    Date,         // aceita ISO, DD/MM/YYYY, MM/DD/YYYY
    Email,
    Phone,
    Currency,     // aceita "R$ 1.234,56" e "1234.56"
    Boolean,      // aceita "sim/não", "true/false", "1/0"
}

/// Validar dados contra schema
fn validate_import_data(
    parsed: &ParsedData,
    schema: &ImportSchema,
) -> Result<ValidatedImport, ApiError> {
    let mut result = ValidatedImport::default();

    // 1. Mapear colunas (com aliases fuzzy)
    let column_mapping = map_columns(&parsed.headers, &schema.columns)?;

    // 2. Verificar colunas obrigatórias
    for required in &schema.required_columns {
        if !column_mapping.contains_key(required) {
            return Err(ApiError::validation(&format!(
                "Coluna obrigatória '{}' não encontrada. Colunas disponíveis: {:?}",
                required, parsed.headers
            )));
        }
    }

    // 3. Validar cada linha
    for (row_idx, row) in parsed.rows.iter().enumerate() {
        let line_num = row_idx + 2;  // +2 porque header = linha 1

        // Pular linhas totalmente vazias
        if row.iter().all(|cell| cell.trim().is_empty()) {
            result.skipped += 1;
            continue;
        }

        let mut row_errors = Vec::new();
        let mut validated_row = HashMap::new();

        for (target_col, source_idx) in &column_mapping {
            let value = row.get(*source_idx).map(|s| s.as_str()).unwrap_or("");
            let col_def = schema.columns.iter().find(|c| &c.name == target_col).unwrap();

            // Validar tipo
            match validate_cell(value, col_def) {
                Ok(parsed_value) => { validated_row.insert(target_col.clone(), parsed_value); }
                Err(e) => row_errors.push(ImportRowError {
                    line: line_num,
                    column: target_col.clone(),
                    value: value.to_string(),
                    error: e,
                }),
            }
        }

        if row_errors.is_empty() {
            result.valid_rows.push(validated_row);
        } else {
            result.errors.extend(row_errors);
            result.skipped += 1;
        }
    }

    Ok(result)
}

// ERRADO: importar dados sem validação → crash em runtime, dados corrompidos
fn bad_import(rows: Vec<Vec<String>>) {
    for row in rows {
        sqlx::query!("INSERT INTO products (name, price) VALUES ($1, $2)",
            row[0],
            row[1].parse::<f64>().unwrap()  // PANIC se "R$ 1.234,56"
        );
    }
}
```

---

## 4. Export — PDF, Excel, CSV

### 4.1 Endpoint de Export Assíncrono

```rust
// CERTO: export assíncrono via job queue para relatórios pesados
#[derive(Debug, Deserialize)]
struct ExportRequest {
    format: ExportFormat,
    filters: ReportFilters,
    #[serde(default = "default_locale")]
    locale: String,            // pt-BR, en-US — afeta formatação
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
enum ExportFormat {
    Pdf,
    Xlsx,
    Csv,
}

/// Export handler — async job para relatórios > 1000 linhas
async fn export_report(
    State(state): State<AppState>,
    tenant: TenantContext,
    Path(report_id): Path<Uuid>,
    Json(req): Json<ExportRequest>,
) -> Result<Json<ExportResponse>, ApiError> {
    // 1. Contar registros para decidir síncrono vs assíncrono
    let row_count = count_report_rows(&state.db, &tenant, report_id, &req.filters).await?;

    if row_count > 1000 {
        // Relatório grande → processar assíncrono
        let job_id = enqueue_export_job(&state, &tenant, report_id, &req).await?;
        return Ok(Json(ExportResponse::Async { job_id }));
    }

    // Relatório pequeno → síncrono
    let data = fetch_report_data(&state.db, &tenant, report_id, &req.filters).await?;
    let bytes = match req.format {
        ExportFormat::Pdf => generate_pdf(&state.tera, &data, &req.locale).await?,
        ExportFormat::Xlsx => generate_xlsx(&data, &req.locale)?,
        ExportFormat::Csv => generate_csv(&data, &req.locale)?,
    };

    let url = upload_to_storage(&state.storage, &tenant, &bytes, &req.format).await?;

    Ok(Json(ExportResponse::Ready { download_url: url, expires_in: 3600 }))
}

// ERRADO: gerar PDF no handler de request com timeout de 30s
// Relatório com 50k linhas vai timeout e matar a request
```

### 4.2 Excel Export (XLSX) com rust_xlsxwriter

```rust
// CERTO: XLSX export com formatação profissional
use rust_xlsxwriter::{Workbook, Format, FormatAlign, Color};

fn generate_xlsx(data: &ReportData, locale: &str) -> Result<Vec<u8>, ReportError> {
    let mut workbook = Workbook::new();
    let worksheet = workbook.add_worksheet();
    worksheet.set_name(&data.title)?;

    // Formatos
    let header_fmt = Format::new()
        .set_bold()
        .set_background_color(Color::RGB(0x1A1A2E))
        .set_font_color(Color::White)
        .set_align(FormatAlign::Center)
        .set_font_size(10.0);

    let currency_fmt = Format::new()
        .set_num_format(r#"R$ #,##0.00"#)
        .set_align(FormatAlign::Right);

    let date_fmt = Format::new()
        .set_num_format("dd/mm/yyyy");

    let number_fmt = Format::new()
        .set_num_format("#,##0")
        .set_align(FormatAlign::Right);

    // Headers
    for (col, column) in data.columns.iter().enumerate() {
        worksheet.write_string(0, col as u16, &column.label)?;
        worksheet.set_column_format(col as u16, &header_fmt)?;
        worksheet.set_column_width(col as u16, column.width.unwrap_or(15) as f64)?;
    }

    // Dados
    for (row_idx, row) in data.rows.iter().enumerate() {
        let row_num = (row_idx + 1) as u32;
        for (col_idx, column) in data.columns.iter().enumerate() {
            let col_num = col_idx as u16;
            let value = &row[&column.key];

            match column.format.as_deref() {
                Some("currency") => {
                    worksheet.write_number(row_num, col_num, value.as_f64())?;
                    worksheet.set_column_format(col_num, &currency_fmt)?;
                }
                Some("date") => {
                    worksheet.write_string(row_num, col_num, &value.as_date_str(locale))?;
                }
                Some("number") => {
                    worksheet.write_number(row_num, col_num, value.as_f64())?;
                    worksheet.set_column_format(col_num, &number_fmt)?;
                }
                _ => {
                    worksheet.write_string(row_num, col_num, &value.as_string())?;
                }
            }
        }
    }

    // Auto-filter
    worksheet.autofilter(0, 0, data.rows.len() as u32, (data.columns.len() - 1) as u16)?;

    // Freeze top row
    worksheet.set_freeze_panes(1, 0)?;

    let buffer = workbook.save_to_buffer()?;
    Ok(buffer)
}
```

### 4.3 CSV Export com Encoding Correto

```rust
// CERTO: CSV export com BOM UTF-8 para compatibilidade com Excel
fn generate_csv(data: &ReportData, locale: &str) -> Result<Vec<u8>, ReportError> {
    let mut writer = csv::WriterBuilder::new()
        .delimiter(if locale.starts_with("pt") { b';' } else { b',' })  // Brasil usa ponto-e-vírgula
        .from_writer(Vec::new());

    // BOM UTF-8 para Excel reconhecer encoding
    let mut output = vec![0xEF, 0xBB, 0xBF];

    // Headers
    let headers: Vec<&str> = data.columns.iter().map(|c| c.label.as_str()).collect();
    writer.write_record(&headers)?;

    // Dados
    for row in &data.rows {
        let values: Vec<String> = data.columns.iter()
            .map(|col| format_value(&row[&col.key], &col.format, locale))
            .collect();
        writer.write_record(&values)?;
    }

    output.extend(writer.into_inner()?);
    Ok(output)
}

// ERRADO: CSV sem BOM, sem considerar locale
fn bad_csv(data: &[Row]) -> String {
    data.iter().map(|r| format!("{},{}", r.name, r.value)).collect::<Vec<_>>().join("\n")
    // sem header, sem BOM, sem escape de vírgulas, sem locale
}
```

---

## 5. Frontend — Report Designer (React)

### 5.1 Template Definition Schema

```typescript
// CERTO: schema tipado para definição de report template
interface ReportTemplate {
  id: string;
  name: string;
  description: string;
  pageSize: 'a4' | 'letter' | 'a3';
  orientation: 'portrait' | 'landscape';
  margins: { top: number; right: number; bottom: number; left: number };

  header: ReportSection;
  body: ReportSection;
  footer: ReportSection;

  dataSource: DataSourceConfig;        // qual query/endpoint alimenta este relatório
  parameters: ReportParameter[];       // filtros configuráveis pelo usuário
  columns: ColumnDefinition[];         // colunas da tabela principal
  groupBy?: GroupDefinition[];         // agrupamento (ex: por mês, por categoria)
  sortBy?: SortDefinition[];
}

interface ColumnDefinition {
  key: string;                         // campo do dataset
  label: string;                       // label exibido no header
  format: 'text' | 'number' | 'currency' | 'date' | 'percentage';
  width?: number;                      // largura em mm
  align?: 'left' | 'center' | 'right';
  aggregation?: 'sum' | 'avg' | 'count' | 'min' | 'max';
  visible: boolean;
  sortable: boolean;
}

interface ReportParameter {
  key: string;
  label: string;
  type: 'date_range' | 'select' | 'multi_select' | 'text' | 'number';
  required: boolean;
  defaultValue?: unknown;
  options?: { value: string; label: string }[];   // para selects
}
```

### 5.2 Report Viewer com Preview e Export

```tsx
// CERTO: Report Viewer com preview, filtros e export
function ReportViewer({ templateId }: { templateId: string }) {
  const { template } = useReportTemplate(templateId);
  const [params, setParams] = useState<Record<string, unknown>>({});
  const { data, isLoading, error } = useReportData(templateId, params);

  const exportMutation = useMutation({
    mutationFn: (format: ExportFormat) =>
      reportService.export(templateId, { format, filters: params }),
    onSuccess: (result) => {
      if (result.type === 'ready') {
        window.open(result.download_url, '_blank');
      } else {
        toast.info('Relatório sendo gerado. Você será notificado quando finalizar.');
      }
    },
  });

  return (
    <div className="report-viewer">
      {/* Parameters bar */}
      <div className="report-params">
        {template.parameters.map((param) => (
          <ReportParamInput
            key={param.key}
            param={param}
            value={params[param.key]}
            onChange={(v) => setParams(p => ({ ...p, [param.key]: v }))}
          />
        ))}
        <div className="export-actions">
          <Button variant="outline" onClick={() => exportMutation.mutate('pdf')}>
            <FileTextIcon /> PDF
          </Button>
          <Button variant="outline" onClick={() => exportMutation.mutate('xlsx')}>
            <TableIcon /> Excel
          </Button>
          <Button variant="outline" onClick={() => exportMutation.mutate('csv')}>
            <FileSpreadsheetIcon /> CSV
          </Button>
        </div>
      </div>

      {/* Report preview */}
      <div className="report-preview">
        {isLoading && <ReportSkeleton template={template} />}
        {error && <ReportError error={error} />}
        {data && (
          <>
            <ReportKpiRow kpis={data.kpis} />
            <ReportDataTable
              columns={template.columns.filter(c => c.visible)}
              rows={data.rows}
              groupBy={template.groupBy}
              sortBy={template.sortBy}
            />
            {data.rows.length > 0 && template.columns.some(c => c.aggregation) && (
              <ReportTotalsRow columns={template.columns} rows={data.rows} />
            )}
          </>
        )}
      </div>
    </div>
  );
}
```

### 5.3 File Import UI — Upload com Preview

```tsx
// CERTO: Import UI com preview, column mapping e validação visual
function FileImporter({ schema, onImport }: FileImporterProps) {
  const [step, setStep] = useState<'upload' | 'mapping' | 'preview' | 'result'>('upload');
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<ParsedPreview | null>(null);
  const [mapping, setMapping] = useState<Record<string, string>>({});

  const uploadMutation = useMutation({
    mutationFn: async (file: File) => {
      const formData = new FormData();
      formData.append('file', file);
      return importService.preview(formData);  // backend retorna primeiras 10 linhas
    },
    onSuccess: (data) => {
      setPreview(data);
      setMapping(autoMapColumns(data.headers, schema.columns));
      setStep('mapping');
    },
  });

  return (
    <div className="file-importer">
      {step === 'upload' && (
        <DropZone
          accept={['.csv', '.xlsx', '.parquet']}
          maxSize={50 * 1024 * 1024}
          onDrop={(file) => { setFile(file); uploadMutation.mutate(file); }}
        />
      )}

      {step === 'mapping' && preview && (
        <ColumnMapper
          sourceColumns={preview.headers}
          targetColumns={schema.columns}
          mapping={mapping}
          onChange={setMapping}
          previewRows={preview.rows.slice(0, 5)}
          onConfirm={() => setStep('preview')}
        />
      )}

      {step === 'preview' && (
        <ImportPreview
          mapping={mapping}
          preview={preview!}
          schema={schema}
          onConfirm={() => executeImport()}
        />
      )}

      {step === 'result' && (
        <ImportResult result={importResult} onClose={() => setStep('upload')} />
      )}
    </div>
  );
}
```

---

## 6. Scheduled Reports — Entrega Automática

```rust
// CERTO: scheduled reports com cron + delivery por email
#[derive(Debug, Deserialize, sqlx::FromRow)]
struct ScheduledReport {
    id: Uuid,
    tenant_id: Uuid,
    report_template_id: Uuid,
    schedule_cron: String,           // "0 8 * * MON" (segundas às 8h)
    format: ExportFormat,
    recipients: Vec<String>,          // emails
    filters: serde_json::Value,
    timezone: String,                 // "America/Sao_Paulo"
    is_active: bool,
    last_run_at: Option<DateTime<Utc>>,
    next_run_at: DateTime<Utc>,
}

/// Job runner que verifica e executa reports agendados
async fn run_scheduled_reports(state: &AppState) {
    let due_reports = sqlx::query_as!(ScheduledReport,
        r#"SELECT * FROM scheduled_reports
           WHERE is_active = TRUE
           AND next_run_at <= NOW()
           ORDER BY next_run_at ASC
           LIMIT 10
           FOR UPDATE SKIP LOCKED"#
    )
    .fetch_all(&state.db)
    .await
    .unwrap_or_default();

    for report in due_reports {
        // Processar em task isolada — falha de um não afeta os outros
        let state = state.clone();
        tokio::spawn(async move {
            if let Err(e) = execute_scheduled_report(&state, &report).await {
                tracing::error!(
                    report_id = %report.id,
                    tenant_id = %report.tenant_id,
                    error = %e,
                    "Scheduled report failed"
                );
                // Registrar falha, notificar admin após 3 falhas consecutivas
            }
        });
    }
}
```

---

## 7. Estrutura de Projeto

```
backend/ (Rust — Axum)
├── src/
│   ├── reports/
│   │   ├── mod.rs
│   │   ├── routes.rs              # Endpoints REST
│   │   ├── service.rs             # Lógica de negócio
│   │   ├── pdf_generator.rs       # Typst/Chromium PDF generation
│   │   ├── xlsx_generator.rs      # rust_xlsxwriter
│   │   ├── csv_generator.rs       # CSV com BOM UTF-8
│   │   └── scheduler.rs           # Cron job para scheduled reports
│   ├── imports/
│   │   ├── mod.rs
│   │   ├── routes.rs              # Upload endpoint
│   │   ├── service.rs             # Orquestração de import
│   │   ├── parsers/
│   │   │   ├── csv_parser.rs      # csv crate + encoding detection
│   │   │   ├── xlsx_parser.rs     # calamine
│   │   │   └── parquet_parser.rs  # polars
│   │   ├── validator.rs           # Schema validation
│   │   └── mapper.rs              # Column mapping + fuzzy match
│   └── templates/
│       └── reports/               # Tera HTML templates
│           ├── base.html
│           ├── sales_report.html
│           └── financial_report.html
│
frontend/ (React)
├── src/features/reports/
│   ├── components/
│   │   ├── ReportViewer.tsx       # Preview + export
│   │   ├── ReportParamInput.tsx   # Filtros (date range, select, etc.)
│   │   ├── ReportDataTable.tsx    # Tabela com sort + group
│   │   ├── ReportKpiRow.tsx       # KPI cards do relatório
│   │   └── ReportTotalsRow.tsx    # Linha de totais com aggregations
│   ├── hooks/
│   │   ├── useReportTemplate.ts
│   │   └── useReportData.ts
│   └── services/
│       └── report.service.ts
├── src/features/imports/
│   ├── components/
│   │   ├── FileImporter.tsx       # Upload + mapping + preview flow
│   │   ├── DropZone.tsx           # Drag-and-drop file upload
│   │   ├── ColumnMapper.tsx       # Mapeamento source → target
│   │   └── ImportResult.tsx       # Resultado com erros/warnings
│   └── services/
│       └── import.service.ts
```

---

## 8. Checklist Senior+ — Report Builder

- [ ] **Template engine tipado** — Tera ou Typst, NUNCA string concatenation manual.
- [ ] **spawn_blocking** — PDF generation SEMPRE em `spawn_blocking` (CPU-bound).
- [ ] **Tamanho máximo** — upload limitado (50MB default), validação antes do parse.
- [ ] **Encoding detection** — CSV detecta UTF-8/Latin-1/Windows-1252 automaticamente.
- [ ] **Delimiter detection** — CSV detecta `,` vs `;` vs `\t` automaticamente.
- [ ] **BOM UTF-8** — CSV export inclui BOM para compatibilidade com Excel.
- [ ] **Locale-aware** — formatação respeita locale (R$ vs $, DD/MM vs MM/DD, `;` vs `,`).
- [ ] **Column mapping** — import oferece mapeamento de colunas com fuzzy match.
- [ ] **Validação em camadas** — tipo/tamanho → parse → schema → business rules.
- [ ] **Async para grandes volumes** — relatórios > 1000 linhas vão para job queue.
- [ ] **Page breaks** — CSS `page-break-inside: avoid` em grupos e totais.
- [ ] **tabular-nums** — `font-variant-numeric: tabular-nums` em todas as colunas numéricas.
- [ ] **Scheduled reports** — cron + email delivery com retry e error tracking.
- [ ] **XLSX formatado** — headers coloridos, autofilter, freeze panes, currency format.
- [ ] **Preview antes de import** — nunca importar sem preview + confirmação do usuário.
- [ ] **Error reporting** — import retorna erros por linha/coluna com valor problemático.
- [ ] **Multi-tenant** — `tenant_id` em toda query, templates e dados isolados por tenant.
