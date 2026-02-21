---
name: FastAPI & Pydantic
description: Validate, generate, and architect Python APIs using FastAPI with Pydantic v2 strict models, async-first patterns, and dependency injection. Enforces typed schemas, centralized error handling, and zero-trust input validation.
---

# FastAPI & Pydantic v2 — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de gerar qualquer módulo**, externalize a arquitetura proposta em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: edite um arquivo por vez, nunca reescreva módulos inteiros.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- Trate **todo input** como hostil. Validação Pydantic é a primeira e última barreira.

## 2. Estrutura de Projeto Obrigatória

```
src/
├── main.py              # app factory, lifespan
├── config.py            # BaseSettings (env)
├── dependencies.py      # Depends() factories
├── models/              # SQLAlchemy/Tortoise ORM
├── schemas/             # Pydantic v2 DTOs
├── routers/             # APIRouter por domínio
├── services/            # Lógica de negócio (injetável)
├── repositories/        # Acesso a dados (injetável)
├── exceptions/          # Exceções customizadas
└── middleware/           # CORS, logging, etc
```

## 3. Pydantic v2 — Dogmas

### 3.1 Sempre usar `model_config = ConfigDict(strict=True)`

```python
# ✅ CERTO — strict mode + validação explícita
from pydantic import BaseModel, ConfigDict, Field, EmailStr

class CreateUserDTO(BaseModel):
    model_config = ConfigDict(strict=True, frozen=True)

    name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    age: int = Field(ge=18, le=120)

# ❌ ERRADO — modelo frouxo, sem validação
class CreateUserDTO(BaseModel):
    name: str
    email: str  # Aceita qualquer string
    age: int    # Aceita negativos
```

### 3.2 Separar DTOs de Input e Output

```python
# ✅ CERTO — DTOs separados
class UserCreateDTO(BaseModel):
    name: str = Field(min_length=2)
    email: EmailStr

class UserResponseDTO(BaseModel):
    id: int
    name: str
    email: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

# ❌ ERRADO — mesmo modelo para tudo
class User(BaseModel):
    id: int | None = None  # Nullable para "servir" create e response
    name: str
    email: str
```

### 3.3 Discriminated Unions para polimorfismo

```python
from pydantic import Discriminator, Tag
from typing import Annotated, Literal, Union

class CreditPayment(BaseModel):
    type: Literal["credit"] = "credit"
    card_number: str
    installments: int = Field(ge=1, le=12)

class PixPayment(BaseModel):
    type: Literal["pix"] = "pix"
    pix_key: str

PaymentDTO = Annotated[
    Union[
        Annotated[CreditPayment, Tag("credit")],
        Annotated[PixPayment, Tag("pix")],
    ],
    Discriminator("type"),
]
```

## 4. Injeção de Dependências — Dogmas

### 4.1 Nunca instanciar serviços diretamente

```python
# ✅ CERTO — inversão de dependência via Depends
from fastapi import Depends

class UserService:
    def __init__(self, repo: UserRepository) -> None:
        self.repo = repo

def get_user_service(
    repo: UserRepository = Depends(get_user_repository),
) -> UserService:
    return UserService(repo=repo)

@router.post("/users")
async def create_user(
    dto: UserCreateDTO,
    service: UserService = Depends(get_user_service),
) -> UserResponseDTO:
    return await service.create(dto)

# ❌ ERRADO — acoplamento direto
@router.post("/users")
async def create_user(dto: UserCreateDTO):
    service = UserService()  # Instancia direta, impossível testar
    return await service.create(dto)
```

### 4.2 Configuração por BaseSettings

```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    database_url: str
    redis_url: str
    secret_key: str  # NUNCA hardcode
    debug: bool = False

    model_config = ConfigDict(env_file=".env", extra="forbid")

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

## 5. Async — Dogmas

- **async def** para todo I/O (database, HTTP, filesystem).
- **def** (sync) apenas para lógica CPU-bound pura.
- Nunca misture sync blocking I/O dentro de async — use `run_in_executor`.

```python
# ✅ CERTO — async para I/O
@router.get("/users/{user_id}")
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user

# ❌ ERRADO — sync bloqueante em contexto async
@router.get("/users/{user_id}")
async def get_user(user_id: int):
    user = db.query(User).get(user_id)  # BLOQUEIA o event loop
    return user
```

## 6. Error Handling — Centralizado

```python
from fastapi import Request
from fastapi.responses import JSONResponse

class AppException(Exception):
    def __init__(self, status_code: int, detail: str, code: str) -> None:
        self.status_code = status_code
        self.detail = detail
        self.code = code

@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.code, "message": exc.detail}},
    )

# Uso nos services:
raise AppException(404, "Usuário não encontrado", "USER_NOT_FOUND")
```

## 7. Segurança Obrigatória

- CORS estrito: listar origens explícitas, nunca `allow_origins=["*"]` em produção.
- Rate limiting via `slowapi` ou middleware customizado.
- Secrets **sempre** via `BaseSettings` + `.env`. Nunca hardcode.
- Helmet-like headers via middleware (HSTS, X-Content-Type-Options).
- Validação de uploads: checar MIME type, tamanho máximo, extensões permitidas.
