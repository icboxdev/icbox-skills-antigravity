---
name: Entity Framework Core 8/9 & Cloud Resilience
description: Validate, execute, and architect C# applications using modern Entity Framework Core 8 & 9. Enforce Cloud Database resilience using Polly, Retries, Circuit Breakers, Bulk Operations, and Compiled Queries for massive IO optimization.
---

# Entity Framework Core 8/9 & Cloud Resilience

Na nuvem (.NET 8 e 9), interrupções transient lines, reboots de balanceadores e network blips no Azure SQL VCore acontecem diariamente. A aplicação não pode explodir "500 Internal Server". O Entity Framework (EF) deve assumir uma resiliência Cloud-Ready usando o framework `Microsoft.Extensions.Resilience` (Polly v8+) e lidar com Otimizações Extremos de I/O em Batchs.

## 🏛️ Dogmas de Arquitetura EF Core em Nuvem

1. **RETRY ON FAILURE É MANDATÓRIO (DI LEVEL):** Ao configurar o `AddDbContextPool`, é ABSOLUTAMENTE OBRIGATÓRIO habilitar o Execution Strategy (Retry automático de Transient Faults). Se o Node do banco sofrer failover, o EF pausará a execução (em backoff exponencial) e re-tentará antes de derrubar o Payload do C#.
2. **APLIQUE MICROSOFT.EXTENSIONS.RESILIENCE PARA CADEIAS EXTERNAS:** Não trate resiliência apenas no DB. Toda vez que uma requisição vier acoplada a chamadas HTTP (Polly Pipelines com Retry e Circuit Breaker habilitados nativamente no DI) DEVE respeitar um "Timeout / Fallback" limite. 
3. **USE `ExecuteUpdateAsync` E `ExecuteDeleteAsync` EM MASSA:** Se você for atualizar o STATUS de 50.000 Orders, VOCÊ SERÁ PENALIZADO em banco de dados na Nuvem caso chame o `SaveChanges()` tradicional (que roda UPDATE Row x Row no log do Tracking). Utilize estritamente os Bulks Set-Based Operations criados no EF Core 7+, que jogam APENAS um `UPDATE ... WHERE ...` massivo num único Roundtrip via TCP.
4. **`AsNoTracking()` PADRÃO EM PURE READS:** O Tracking Mechanism (Change Tracker) devora RAM assustadoramente no .NET (criando Snapshots de objetos). Qualquer Query em API cujo intuito é apenas "Devolver um DTO pro Usuário via GET", OBRIGATORIAMENTE DEVE estar acompanhada da instrução `.AsNoTracking()`.
5. **DBCONTEXT POOLING SOBRE SCOPED CREATION:** A criação de uma instância `DbContext` não é barata de se calcular no Heap da nuvem. OBRIGATÓRIO configurar `AddDbContextPool`, o qual instrui o framework a reutilizar (recycling) os Contextos injetados, poupando overhead na alocação da instância e GC (Garbage Collection).

## 🛑 Padrões (Certo vs Errado)

### Lidando Trovões de Rede (Resilience & Retry no Startup)

**❌ ERRADO** (Nenhum execution strategy; 1 microqueda derruba a API. Instabilidade):
```csharp
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"))
);
// Quando a cloud desligar o Azure SQL por 2 segundos p/ patching, milhentos erros 500.
```

**✅ CERTO** (EF Core Resilience + DbContext Pooling nativo):
```csharp
builder.Services.AddDbContextPool<AppDbContext>(options =>
{
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"),
        sqlServerOptionsAction: sqlOptions =>
        {
            // O próprio EF identifica falhas "Transient", congela (backoff) e re-envia o pacote!
            sqlOptions.EnableRetryOnFailure(
                maxRetryCount: 5,
                maxRetryDelay: TimeSpan.FromSeconds(30),
                errorNumbersToAdd: null); // Pode adicionar IDs de erro SQL customizados aqui.
        });
});
```

### Otimização Massiva de Cloud I/O (AsNoTracking e EF Batch Operations)

**❌ ERRADO** (Atualização For-Each e Trackers gigantes destruindo Memória / I/O da Nuvem):
```csharp
var archiveBoundary = DateTime.UtcNow.AddYears(-1);
// 1. SELECT gigante jogado inteirinho na Memória do Servidor App e "Rastreado"
var expiredTokens = await _context.Tokens
    .Where(t => t.ExpiresAt < archiveBoundary)
    .ToListAsync(); 

// 2. O .NET Itera no Heap alocando status
foreach(var tk in expiredTokens) { tk.Status = "Archived"; }

// 3. Faz Round-Trips repetidos "UPDATE .. WHERE ID=1", "UPDATE.. WHERE ID=2" no Cloud DB
await _context.SaveChangesAsync(); 
```

**✅ CERTO** (Delegando o Set-Based Execution puro pro Motor do SQL via LINQ - Zero Memory Overhead):
```csharp
var archiveBoundary = DateTime.UtcNow.AddYears(-1);

// A mágica do EF Core 8:
// ISSO ENVIA UMA QUERIE CRUA "UPDATE Tokens SET Status = 'Archived' WHERE ExpiresAt < ...".
// O Change Tracker (Memória local do app) NEM é acionado. Zero alocação gigante. 1 Único ping de Rede.
int affectedRows = await _context.Tokens
    .Where(t => t.ExpiresAt < archiveBoundary)
    .ExecuteUpdateAsync(s => s.SetProperty(t => t.Status, "Archived"));
```

### Problemas de Fetch N+1 e Cloud Latency Penalty

Nunca utilize a clássica e perigosa função de **Lazy Loading do Entity Framework** no ecossistema de nuvem asincrono (Virtual Proxy navigation properties). Se habilitar `"UseLazyLoadingProxies"`, acessos dentro do mapeamento de DTO causarão queries "Síncronas" invisíveis bloqueando o Threapool principal e empilhando latência de nuvem "Ida e Volta". OBRIGATÓRIO utilizar `Include(...)` ou projecão pura com `.Select()`.

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

