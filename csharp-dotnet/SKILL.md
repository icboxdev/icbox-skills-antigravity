---
name: C# / .NET (ASP.NET Core)
description: Validate, architect, and generate C# applications using ASP.NET Core, Entity Framework Core, Minimal APIs, and Clean Architecture. Enforces strict nullable types, primary constructors, record DTOs, dependency injection, middleware pipelines, and zero-trust input validation.
---

# C# / .NET — Diretrizes Sênior

## 1. Princípio Zero: Zero-Trust e Context Limits

- **Nullable Reference Types SEMPRE habilitado**: `<Nullable>enable</Nullable>` no `.csproj` — sem exceção.
- **Sanitização Universal**: Todo input externo é hostil. Valide com FluentValidation ou Data Annotations. Client validation é UX, não segurança.
- **Micro-commits**: Uma feature, um commit. Não crie Controller + Service + Repository + DbContext no mesmo prompt. Vá passo a passo.
- **Externalize Contexto**: Para refatorações complexas, crie/atualize `AI.md` e `ROADMAP.md` antes de codar.

## 2. Versões e Configuração Obrigatória

### Target Framework

- **Target mínimo**: .NET 8 LTS (preferencialmente .NET 9+).
- Sempre gere `.csproj` com Nullable e ImplicitUsings habilitados:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  </PropertyGroup>
</Project>
```

### `any` equivalente — PROIBIDO

- **NUNCA use `dynamic`** exceto em cenários de interop COM comprovados.
- **NUNCA use `object` como substituto de tipo** — use generics ou `unknown` patterns com pattern matching.
- **NUNCA desabilite nullable warnings** com `#nullable disable` ou `!` (null-forgiving) sem justificativa documentada.

## 3. Arquitetura — Clean Architecture + DDD

### Estrutura de Projeto Obrigatória

```
# CERTO: Clean Architecture / Modular
src/
├── Api/                           # Presentation Layer
│   ├── Controllers/               # Thin controllers
│   ├── Endpoints/                 # Minimal API endpoint groups
│   ├── Middleware/                 # Custom middleware
│   ├── Filters/                   # Exception filters
│   └── Program.cs                 # Composition root
├── Application/                   # Use Cases / Business Logic
│   ├── DTOs/                      # Input/Output contracts
│   ├── Services/                  # Application services
│   ├── Interfaces/                # Port abstractions
│   ├── Validators/                # FluentValidation validators
│   └── Mappings/                  # AutoMapper profiles
├── Domain/                        # Enterprise business rules
│   ├── Entities/                  # Domain models
│   ├── ValueObjects/              # Immutable value types
│   ├── Enums/                     # Domain enums
│   └── Events/                    # Domain events
├── Infrastructure/                # External concerns
│   ├── Data/                      # EF Core DbContext + configs
│   │   ├── Configurations/        # IEntityTypeConfiguration<T>
│   │   ├── Migrations/            # EF Migrations
│   │   └── AppDbContext.cs
│   ├── Repositories/              # Repository implementations
│   ├── Services/                  # External service adapters
│   └── DependencyInjection.cs     # Service registration extensions
└── Shared/                        # Cross-cutting concerns
    ├── Exceptions/                # Custom exception types
    ├── Extensions/                # Extension methods
    └── Guards/                    # Guard clauses

# ERRADO: Flat structure sem camadas
src/
├── Controllers/
├── Models/                        # Mistura entidade + DTO + ViewModel
├── Data/
└── Helpers/
```

### Dogmas de Arquitetura

- SEMPRE separe: **Controllers** (thin) → **Services** (logic) → **Repositories** (data).
- SEMPRE use **interfaces** para abstrair dependências externas (DB, HTTP, Cache).
- SEMPRE use **DTOs** na fronteira de entrada/saída — nunca exponha entidades EF Core diretamente.
- NUNCA coloque lógica de negócio em controllers — eles apenas orquestram.
- NUNCA acesse `DbContext` diretamente do controller — sempre via service → repository.
- NUNCA crie classes com mais de 1 responsabilidade (SRP).

## 4. Tipos Modernos: Records, Primary Constructors, Pattern Matching

### Records para DTOs e Value Objects

```csharp
// CERTO: Record para DTO imutável (posicional)
public record CreateProjectRequest(
    string Name,
    string? Description,
    ProjectType Type
);

// CERTO: Record para response
public record ProjectResponse(
    Guid Id,
    string Name,
    string Status,
    DateTime CreatedAt
);

// ERRADO: Classe mutável como DTO
public class CreateProjectRequest
{
    public string Name { get; set; } = "";  // mutável, default vazio
    public object Description { get; set; }  // object genérico!
}
```

### Primary Constructors para DI (C# 12+)

```csharp
// CERTO: Primary constructor para DI
public class ProjectService(
    IProjectRepository repository,
    ILogger<ProjectService> logger,
    IValidator<CreateProjectRequest> validator)
{
    public async Task<ProjectResponse> CreateAsync(CreateProjectRequest request)
    {
        var result = await validator.ValidateAsync(request);
        if (!result.IsValid)
            throw new ValidationException(result.Errors);

        logger.LogInformation("Creating project: {Name}", request.Name);
        var entity = await repository.CreateAsync(request);
        return entity.ToResponse();
    }
}

// ERRADO: Campos manuais repetitivos
public class ProjectService
{
    private readonly IProjectRepository _repository;
    private readonly ILogger<ProjectService> _logger;

    public ProjectService(IProjectRepository repository, ILogger<ProjectService> logger)
    {
        _repository = repository;
        _logger = logger;
    }
}
```

### Pattern Matching — Use Sempre que Possível

```csharp
// CERTO: Pattern matching exaustivo
public string GetStatusLabel(ProjectStatus status) => status switch
{
    ProjectStatus.Draft => "Rascunho",
    ProjectStatus.Active => "Ativo",
    ProjectStatus.Paused => "Pausado",
    ProjectStatus.Completed => "Concluído",
    ProjectStatus.Archived => "Arquivado",
    _ => throw new ArgumentOutOfRangeException(nameof(status))
};

// CERTO: Pattern matching em validação
public IActionResult Process(object input) => input switch
{
    string s when s.Length > 0 => Ok(s),
    int n when n > 0 => Ok(n),
    null => BadRequest("Input cannot be null"),
    _ => BadRequest("Unsupported input type")
};

// ERRADO: if-else chain
public string GetStatusLabel(ProjectStatus status)
{
    if (status == ProjectStatus.Draft) return "Rascunho";
    else if (status == ProjectStatus.Active) return "Ativo";
    else return "Desconhecido"; // silenciosamente ignora novos status
}
```

## 5. ASP.NET Core — API Design

### Minimal APIs (Preferido para Microservices)

```csharp
// CERTO: Minimal API com endpoint groups
public static class ProjectEndpoints
{
    public static void MapProjectEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/projects")
            .WithTags("Projects")
            .RequireAuthorization();

        group.MapGet("/", GetAll);
        group.MapGet("/{id:guid}", GetById);
        group.MapPost("/", Create);
        group.MapPut("/{id:guid}", Update);
        group.MapDelete("/{id:guid}", Delete);
    }

    private static async Task<IResult> GetAll(
        IProjectService service,
        [AsParameters] PaginationQuery query)
    {
        var result = await service.GetAllAsync(query);
        return TypedResults.Ok(result);
    }

    private static async Task<IResult> Create(
        IProjectService service,
        CreateProjectRequest request,
        IValidator<CreateProjectRequest> validator)
    {
        var validation = await validator.ValidateAsync(request);
        if (!validation.IsValid)
            return TypedResults.ValidationProblem(validation.ToDictionary());

        var project = await service.CreateAsync(request);
        return TypedResults.Created($"/api/v1/projects/{project.Id}", project);
    }
}
```

### Controllers (Para APIs maiores / MVC)

```csharp
// CERTO: Thin controller com DI via primary constructor
[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public class ProjectsController(IProjectService service) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<ProjectResponse>), 200)]
    public async Task<IActionResult> GetAll([FromQuery] PaginationQuery query)
        => Ok(await service.GetAllAsync(query));

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ProjectResponse), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetById(Guid id)
    {
        var project = await service.GetByIdAsync(id);
        return project is null ? NotFound() : Ok(project);
    }

    [HttpPost]
    [ProducesResponseType(typeof(ProjectResponse), 201)]
    [ProducesResponseType(typeof(ValidationProblemDetails), 400)]
    public async Task<IActionResult> Create(CreateProjectRequest request)
    {
        var result = await service.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }
}

// ERRADO: Fat controller com lógica de negócio
[ApiController]
public class ProjectsController : ControllerBase
{
    private readonly AppDbContext _db; // DbContext direto no controller!

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] dynamic body) // dynamic!
    {
        var project = new Project { Name = body.name }; // sem validação!
        _db.Projects.Add(project);
        await _db.SaveChangesAsync();
        return Ok(project); // expõe entidade EF!
    }
}
```

## 6. Entity Framework Core — Data Access

### DbContext e Configuration

```csharp
// CERTO: DbContext limpo + Fluent API configurations separadas
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}

// Configuração separada por entidade
public class ProjectConfiguration : IEntityTypeConfiguration<Project>
{
    public void Configure(EntityTypeBuilder<Project> builder)
    {
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Name).HasMaxLength(100).IsRequired();
        builder.Property(p => p.Status).HasConversion<string>();
        builder.HasIndex(p => new { p.OwnerId, p.Status });
        builder.HasIndex(p => new { p.Status, p.CreatedAt });
        builder.HasOne(p => p.Owner)
            .WithMany(u => u.Projects)
            .HasForeignKey(p => p.OwnerId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}

// ERRADO: Annotations + config inline
public class Project
{
    [Key]
    public int Id { get; set; }
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = ""; // mistura concern
}
```

### Repository Pattern

```csharp
// CERTO: Interface + implementação separadas
public interface IProjectRepository
{
    Task<Project?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task<PagedResult<Project>> GetAllAsync(PaginationQuery query, CancellationToken ct = default);
    Task<Project> CreateAsync(Project entity, CancellationToken ct = default);
    Task UpdateAsync(Project entity, CancellationToken ct = default);
    Task DeleteAsync(Guid id, CancellationToken ct = default);
}

public class ProjectRepository(AppDbContext db) : IProjectRepository
{
    public async Task<Project?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => await db.Projects
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == id, ct);

    public async Task<PagedResult<Project>> GetAllAsync(
        PaginationQuery query, CancellationToken ct = default)
    {
        var queryable = db.Projects.AsNoTracking();

        var total = await queryable.CountAsync(ct);
        var items = await queryable
            .OrderByDescending(p => p.CreatedAt)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(ct);

        return new PagedResult<Project>(items, total, query.Page, query.PageSize);
    }
}

// ERRADO: Sem AsNoTracking, sem paginação
public async Task<List<Project>> GetAll()
    => await db.Projects.Include(p => p.Owner).ToListAsync(); // tracking + N+1 potencial
```

### Migrations — Disciplina

- SEMPRE use migrations versionadas: `dotnet ef migrations add NomeDaMigration`.
- NUNCA altere migrations já aplicadas — crie uma nova.
- SEMPRE revise o SQL gerado: `dotnet ef migrations script`.
- SEMPRE use `CancellationToken` em queries async.

## 7. Dependency Injection — Composition Root

```csharp
// CERTO: Extensions para registro modular de serviços
public static class DependencyInjection
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddScoped<IProjectService, ProjectService>();
        services.AddScoped<IUserService, UserService>();
        services.AddValidatorsFromAssemblyContaining<CreateProjectRequestValidator>();
        return services;
    }

    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration config)
    {
        services.AddDbContext<AppDbContext>(options =>
            options.UseNpgsql(config.GetConnectionString("DefaultConnection")));

        services.AddScoped<IProjectRepository, ProjectRepository>();
        services.AddScoped<IUserRepository, UserRepository>();

        return services;
    }
}

// Program.cs — Limpo e declarativo
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApplicationServices();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();

// ERRADO: Tudo amontoado no Program.cs com 200+ linhas de registros
```

### Lifetimes — Regras

| Lifetime    | Quando usar                                     |
| ----------- | ----------------------------------------------- |
| `Transient` | Stateless helpers, validators, factories        |
| `Scoped`    | Services, Repositories, DbContext (per-request) |
| `Singleton` | Caching, HttpClient factories, config objects   |

- NUNCA injete `Scoped` em `Singleton` — causa captive dependency bug.
- SEMPRE use `IHttpClientFactory` em vez de `new HttpClient()`.

## 8. Error Handling — Problem Details (RFC 7807)

```csharp
// CERTO: Global exception handler com Problem Details
public class GlobalExceptionHandler(
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context,
        Exception exception,
        CancellationToken ct)
    {
        logger.LogError(exception, "Unhandled exception: {Message}", exception.Message);

        var problemDetails = exception switch
        {
            ValidationException ex => new ProblemDetails
            {
                Status = StatusCodes.Status400BadRequest,
                Title = "Validation Error",
                Detail = ex.Message,
                Type = "https://tools.ietf.org/html/rfc7231#section-6.5.1"
            },
            NotFoundException ex => new ProblemDetails
            {
                Status = StatusCodes.Status404NotFound,
                Title = "Not Found",
                Detail = ex.Message
            },
            UnauthorizedAccessException => new ProblemDetails
            {
                Status = StatusCodes.Status403Forbidden,
                Title = "Forbidden"
            },
            _ => new ProblemDetails
            {
                Status = StatusCodes.Status500InternalServerError,
                Title = "Internal Server Error",
                Detail = "An unexpected error occurred"
            }
        };

        context.Response.StatusCode = problemDetails.Status ?? 500;
        await context.Response.WriteAsJsonAsync(problemDetails, ct);
        return true;
    }
}

// Registro no Program.cs
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();
app.UseExceptionHandler();

// ERRADO: try-catch em todo controller com mensagens inconsistentes
[HttpGet("{id}")]
public async Task<IActionResult> Get(int id)
{
    try { return Ok(await _service.Get(id)); }
    catch (Exception ex) { return StatusCode(500, ex.Message); } // vaza stack trace!
}
```

## 9. Middleware Pipeline — Ordem Obrigatória

```csharp
// CERTO: Ordem correta dos middlewares
app.UseExceptionHandler();      // 1. Global error handling
app.UseHsts();                   // 2. HSTS (produção)
app.UseHttpsRedirection();       // 3. Force HTTPS
app.UseCors();                   // 4. CORS antes de auth
app.UseAuthentication();         // 5. Quem é você?
app.UseAuthorization();          // 6. O que pode fazer?
app.UseRateLimiter();            // 7. Rate limiting
app.MapControllers();            // 8. Endpoints

// ERRADO: Ordem trocada — CORS após Auth quebra preflight
app.UseAuthentication();
app.UseCors();                   // preflight falha com 401!
```

## 10. Auth & Security

- SEMPRE use **ASP.NET Identity** ou provedor externo (Supabase, Auth0).
- SEMPRE armazene tokens em **httpOnly, Secure, SameSite=Strict** cookies.
- SEMPRE use **[Authorize]** attribute — padrão seguro.
- SEMPRE valide **inputs no servidor** com FluentValidation ou Data Annotations.
- SEMPRE use **parameterized queries** (EF Core faz automaticamente).
- SEMPRE implemente **rate limiting** com `AddRateLimiter()`.
- NUNCA exponha connection strings ou secrets no código.
- NUNCA use `string.Format` ou interpolação para SQL — sempre EF ou Dapper parametrizado.
- NUNCA desabilite HTTPS em produção.
- NUNCA log dados sensíveis (senhas, tokens, PII).

```csharp
// CERTO: Rate limiting por endpoint
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("login", opt =>
    {
        opt.PermitLimit = 5;
        opt.Window = TimeSpan.FromMinutes(1);
        opt.QueueLimit = 0;
    });
});

[HttpPost("login")]
[EnableRateLimiting("login")]
public async Task<IActionResult> Login(LoginRequest request) { ... }
```

## 11. Performance

- SEMPRE use **`AsNoTracking()`** para queries de leitura.
- SEMPRE use **`CancellationToken`** em todos os métodos async.
- SEMPRE use **`IHttpClientFactory`** — nunca `new HttpClient()`.
- SEMPRE use **response caching** e **output caching** quando aplicável.
- SEMPRE use **`Select()`** para projetar apenas campos necessários — nunca `SELECT *`.
- SEMPRE use **bulk operations** (EF Core 8+) para inserções/atualizações em massa.
- NUNCA bloqueie threads com `.Result` ou `.Wait()` — sempre `await`.
- NUNCA use `Task.Run()` em código ASP.NET Core server-side para I/O bound work.

```csharp
// CERTO: Query otimizada
var projects = await db.Projects
    .AsNoTracking()
    .Where(p => p.OwnerId == userId && p.Status == ProjectStatus.Active)
    .Select(p => new ProjectResponse(p.Id, p.Name, p.Status.ToString(), p.CreatedAt))
    .OrderByDescending(p => p.CreatedAt)
    .Take(20)
    .ToListAsync(ct);

// ERRADO: Carrega tudo, converte em memória
var projects = await db.Projects.ToListAsync(); // carrega TUDO
var response = projects
    .Where(p => p.OwnerId == userId) // filtra em memória!
    .Select(p => new ProjectResponse(p.Id, p.Name, ...))
    .ToList();
```

## 12. Testing — xUnit + FluentAssertions

```csharp
// CERTO: Test com Arrange-Act-Assert
public class ProjectServiceTests
{
    [Fact]
    public async Task CreateAsync_ValidRequest_ReturnsProject()
    {
        // Arrange
        var mockRepo = new Mock<IProjectRepository>();
        var mockValidator = new Mock<IValidator<CreateProjectRequest>>();
        mockValidator.Setup(v => v.ValidateAsync(It.IsAny<CreateProjectRequest>(), default))
            .ReturnsAsync(new ValidationResult());
        mockRepo.Setup(r => r.CreateAsync(It.IsAny<Project>(), default))
            .ReturnsAsync(FakeProject.Create());

        var service = new ProjectService(mockRepo.Object, Mock.Of<ILogger<ProjectService>>(), mockValidator.Object);

        // Act
        var result = await service.CreateAsync(new CreateProjectRequest("Test", null, ProjectType.Internal));

        // Assert
        result.Should().NotBeNull();
        result.Name.Should().Be("Test");
        mockRepo.Verify(r => r.CreateAsync(It.IsAny<Project>(), default), Times.Once);
    }
}

// ERRADO: Sem mock, teste acoplado ao DB
[Fact]
public async Task Create_Works()
{
    var db = new AppDbContext(); // sem mock, depende do DB real
    var service = new ProjectService(db);
    var result = await service.CreateAsync(...);
    Assert.NotNull(result); // assert fraco
}
```

## 13. Docker — Multi-Stage Build

```dockerfile
# CERTO: Multi-stage para .NET
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser
COPY --from=build /app/publish .
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT ["dotnet", "Api.dll"]

# ERRADO: SDK em produção, root user
FROM mcr.microsoft.com/dotnet/sdk:9.0
COPY . .
RUN dotnet run  # SDK pesado + root!
```

## 14. Ferramentas Essenciais (2025)

| Categoria      | Ferramenta                     | Alternativa                  |
| -------------- | ------------------------------ | ---------------------------- |
| **Runtime**    | .NET 9 (LTS: .NET 8)           | —                            |
| **Framework**  | ASP.NET Core (Minimal API)     | Carter, FastEndpoints        |
| **ORM**        | Entity Framework Core 9        | Dapper, RepoDB               |
| **Validation** | FluentValidation               | Data Annotations             |
| **Auth**       | ASP.NET Identity / Supabase    | Auth0, Duende IdentityServer |
| **Mapping**    | Mapster / AutoMapper           | Manual mapping               |
| **Testing**    | xUnit + Moq + FluentAssertions | NUnit, Bogus                 |
| **Logging**    | Serilog (structured)           | NLog, built-in ILogger       |
| **Cache**      | Redis (StackExchange.Redis)    | IMemoryCache, FusionCache    |
| **API Docs**   | Swagger / Scalar               | NSwag                        |
| **Container**  | Docker + Compose               | Podman                       |
| **CI/CD**      | GitHub Actions                 | Azure DevOps, GitLab CI      |
| **Database**   | PostgreSQL (Npgsql)            | SQL Server, MySQL            |

## Resumo do Escopo

Você só atua quando orquestrando, debugando ou gerando C# / .NET. Pare sua tarefa e peça aprovação após fechar a construção arquitetural (Solution, Projects, Entities, Services, Controllers). Sempre valide com `dotnet build --warnaserrors` antes de commitar.
