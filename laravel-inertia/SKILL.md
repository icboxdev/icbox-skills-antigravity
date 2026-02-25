---
name: Laravel & Inertia
description: Validate, generate, and architect Laravel applications with Inertia.js, enforcing skinny controllers, FormRequest validation, Eloquent best practices, and domain-driven service layers.
---

# Laravel & Inertia.js — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de gerar qualquer feature**, externalize a arquitetura proposta em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: edite um controller/service por vez, nunca reescreva módulos inteiros.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- Trate **todo input** como hostil. FormRequest é a barreira obrigatória.
- **Strict PHP Obrigatório**: Todo arquivo PHP gerado DEVE iniciar com `declare(strict_types=1);`.
- Use PHP 8.2+ `readonly class` para DTOs e Actions que não devem ter estado alterado.

## 2. Estrutura de Projeto (Laravel 11+)

```
app/
├── Http/
│   ├── Controllers/       # Skinny — máx 5 métodos CRUD
│   ├── Requests/          # FormRequest por ação
│   └── Resources/         # API Resources (serialização)
├── Models/                # Eloquent (scopes, casts, relations)
├── Services/              # Lógica de negócio
├── Repositories/          # (opcional) Abstração de queries complexas
├── Actions/               # Single-action classes (invokable)
├── Policies/              # Authorization
├── Events/
├── Jobs/
└── Enums/                 # PHP 8.1+ backed enums
bootstrap/
└── app.php                # Registro de middlewares e exceptions (L11+)
```

## 3. Controllers — Skinny

```php
<?php

declare(strict_types=1);

namespace App\Http\Controllers;

// ✅ CERTO — controller delega para service, usa FormRequest
class UserController extends Controller
{
    public function store(
        StoreUserRequest $request,  // Validação automática
        UserService $service,       // Injeção de dependência
    ): RedirectResponse {
        $service->create($request->validated());

        return redirect()->route('users.index')
            ->with('success', 'Usuário criado.');
    }
}

// ❌ ERRADO — controller gordo com lógica + validação inline
class UserController extends Controller
{
    public function store(Request $request)
    {
        $request->validate(['name' => 'required']); // Inline!
        $user = new User();
        $user->name = $request->name;
        $user->email = $request->email;
        $user->password = Hash::make($request->password);
        $user->save();
        // 50+ linhas de lógica aqui...
    }
}
```

## 4. FormRequest — Sempre

```php
// ✅ CERTO — FormRequest dedicado
class StoreUserRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', User::class);
    }

    /** @return array<string, mixed> */
    public function rules(): array
    {
        return [
            'name'     => ['required', 'string', 'min:2', 'max:100'],
            'email'    => ['required', 'email', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            'role'     => ['required', Rule::enum(UserRole::class)],
        ];
    }
}

// ❌ ERRADO — validação inline no controller
$request->validate(['name' => 'required']);
```

## 5. Eloquent — Dogmas

### 5.1 Eager Loading obrigatório

```php
// ✅ CERTO — eager loading explícito
$users = User::with(['posts', 'profile'])->paginate(20);

// ❌ ERRADO — N+1 query
$users = User::all();
foreach ($users as $user) {
    echo $user->posts->count(); // Query por iteração!
}
```

### 5.2 Query Scopes para reutilização

```php
// ✅ CERTO — scope reutilizável
class User extends Model
{
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', UserStatus::Active);
    }
}

// Uso: User::active()->with('posts')->paginate(20);
```

### 5.3 API Resources para serialização

```php
// ✅ CERTO — Resource controla o output
class UserResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        return [
            'id'    => $this->id,
            'name'  => $this->name,
            'email' => $this->email,
            'posts_count' => $this->whenCounted('posts'),
            'created_at'  => $this->created_at->toISOString(),
        ];
    }
}

// ❌ ERRADO — retornar model diretamente (expõe tudo)
return response()->json($user);
```

## 6. Inertia.js — Padrões

```php
// ✅ CERTO — props tipadas + partial reloads
return Inertia::render('Users/Index', [
    'users'   => fn () => UserResource::collection(
        User::active()->with('profile')->paginate(20)
    ),
    'filters' => $request->only(['search', 'status']),
]);

// Frontend (Vue/React) recebe como props tipadas
```

- **Lazy props** com `fn () =>` para dados pesados (carregam sob demanda).
- **Shared data** via `HandleInertiaRequests` middleware para auth/flash.
- **Partial reloads** com `router.reload({ only: ['users'] })`.

## 7. Segurança

- Policies para **toda** autorização. Nunca checar roles inline.
- CSRF ativo em todas as rotas web. Inertia já gerencia automaticamente.
- Rate limiting em rotas de login/API via `throttle` middleware.
- Secrets via `.env`. Nunca hardcode.
- Mass assignment protegido: usar `$fillable` explícito nos Models.
