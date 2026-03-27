---
name: SQLAlchemy 2.0 & Async Python
description: Architect, generate, and optimize Python APIs using SQLAlchemy 2.0 with native async/await, integrating safely with FastAPI, and mitigating N+1 Lazy Loading pitfalls in concurrent environments.
---

# SQLAlchemy 2.0 & Async Python

SQLAlchemy 2.0 abraçou integralmente o `asyncio` e forçou o abandono das query patterns implícitas antigas (lazy loading escondido) que causavam Deadlocks da Event Loop e travavam APIs FastAPI de alto fluxo.

## 🏛️ Dogmas de Arquitetura Async SQLAlchemy 2.0

1. **ASYNC_ENGINE & SESSIONMAKER GLOBAIS:** O `AsyncEngine` (Pool de Conexões assíncronas do banco) OBRIGATORIAMENTE deve ser instanciado uma única vez (Lifespan Startup) na API FastAPI e ser repassado ao `async_sessionmaker`. NUNCA recrie engines por request; reaproveite o pool global.
2. **ISOLAMENTO POR DEPENDENCY INJECTION (FastAPI Yield):** Utilize a interface `Depends()` do FastAPI atrelada a uma função geradora (generator) usando fechamento de bloco léxico (`async with AsyncSession(...)`) para garantir que 1 Request assuma e destrua rigidamente 1 Transação de banco segura, previnindo "Connection Leaks". Assuma sempre auto-commit=False.
3. **EXPIRE_ON_COMMIT = FALSE:** Em arquiteturas assincronas onde você retorna o Modelo direto para serialização do Pydantic (em background task ou pós-request), defina o `async_sessionmaker` com `expire_on_commit=False`. Isso impede que o SQLAlchemy dê um "raise exception" dizendo que o Objeto Expirou quando a thread principal fechar.
4. **N+1 PROBLEM EM ASYNC (LAZY="RAISE"):** O calcanhar de aquiles do Python Asyncio é o bloqueio Implícito. O SQLAlchemy não permite rodar operações de Banco de Dados sem um `await` expresso. Por padrão, ler os itens filhos (`user.posts`) sem tê-los retornado no SELECT inicial dispara Erros Assíncronos no SQLa2.0 ou degrada terrivelmente I/O. **OBRIGATÓRIO** utilizar estratégias de `selectinload` ou colocar `lazy='raise'` na Entity Base para expor bugs precocemente.
5. **A CADEIA `awaitable_attrs` É PARA CASOS EXTREMOS:** O SQLa +2.0.13 trouxe `awaitable_attrs` onde far-se-ia `await user.awaitable_attrs.posts`. No entanto, como arquiteto Python MANTENHA-SE AFASTADO dessa tática em código de fluxo quente, pois isso vai gerar requisições I/O sequenciais ruins na tela de Response. Prefira sempre Eager Loading (`selectinload()`).

## 🛑 Padrões (Certo vs Errado)

### Configuração Core Async FastAPI

**❌ ERRADO** (Recriar session em controladores e travar thread síncrona):
```python
from sqlalchemy.orm import Session # Síncrono

@app.get("/users")
def get_users():
    db = Session(engine) # Trava o Event Loop em picos de requisição
    users = db.query(User).all()
    db.close()
    return users
```

**✅ CERTO** (Async Engine com Dependency Injection Segura):
```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from fastapi import Depends

engine = create_async_engine("postgresql+asyncpg://user:pass@host/db", echo=False)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

# Dependency Pattern
async def get_db():
    async with AsyncSessionLocal() as session:
        yield session # Cede para o Endpoint; fecha sozinho ao fim graças ao Generator Context.

@app.get("/users")
async def get_users(db: AsyncSession = Depends(get_db)):
    # 2.0 Sync/Async Execute Pattern 
    stmt = select(User)
    result = await db.execute(stmt)
    return result.scalars().all()
```

### O Problema N+1 com Relações Assíncronas

**❌ ERRADO** (Retornar coleções com Lazy Load num Async Environment - Explodirá MissingGreenletException ou causará Selects lentos sequenciais no Pydantic dump):
```python
# Model
class User(Base):
    posts = relationship("Post") # Lazy load clássico implícito

# Route
@app.get("/users")
async def get_users_and_posts(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User))
    users = result.scalars().all()
    # Quando o Pydantic / FastAPI for dar JSON Serialize neste `users`, 
    # ele acessará users[0].posts, que tentará uma Query I/O Bloqueante SEM "await". FATAL ERROR.
    return users 
```

**✅ CERTO** (Select In Load = Eager Loading no 2.0 Execute Pattern):
```python
from sqlalchemy.orm import selectinload

@app.get("/users")
async def get_users_and_posts(db: AsyncSession = Depends(get_db)):
    # SELECTINLOAD dispara UMA ÚNICA query paralela: SELECT * FROM posts WHERE user_id IN (1,2,3...)
    # Nunca gera problema "Multi-Row-Duplication" de JOINEDLOAD
    stmt = select(User).options(selectinload(User.posts))
    
    result = await db.execute(stmt)
    users = result.scalars().all()
    # Perfeitamente carregado, 100% thread-safe no event loop quando Pydantic formatá-los.
    return users
```

## Regra: Scripts Temporários

> Scripts auxiliares gerados pelo Agente para acelerar tarefas DEVEM ser criados exclusivamente em `/tmp/` e removidos após uso. NUNCA criar arquivos temporários dentro do diretório do projeto.

