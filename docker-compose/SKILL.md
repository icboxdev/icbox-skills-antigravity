---
name: Docker & Docker Compose
description: Validate, generate, and optimize Dockerfiles and Docker Compose configurations enforcing multi-stage builds, non-root execution, healthchecks, named networks, volume hygiene, and secrets management.
---

# Docker & Docker Compose — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de dockerizar**, externalize a arquitetura de serviços em um artefato (`AI.md`).
- Faça **micro-commits**: configure um service por vez no compose.
- Sempre rodar `docker compose config` para validar YAML antes de subir.
- **Secrets nunca em Dockerfile ou docker-compose.yml** — sempre via `.env` com referência.
- `.dockerignore` é obrigatório em todo projeto com Dockerfile.

## 2. Dockerfile — Multi-Stage Build

```dockerfile
# ✅ CERTO — multi-stage com non-root user
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --ignore-scripts
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/package.json ./

USER appuser
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

```dockerfile
# ❌ ERRADO — single stage, root, copia tudo
FROM node:20
WORKDIR /app
COPY . .                    # Copia node_modules, .env, .git!
RUN npm install             # Instala devDependencies!
CMD ["npm", "start"]        # Roda como root!
```

### .dockerignore obrigatório

```
node_modules
.env*
.git
.gitignore
dist
*.md
docker-compose*.yml
```

## 3. Docker Compose — Dogmas

### 3.1 Estrutura com networks e healthchecks

```yaml
# ✅ CERTO — services isolados, healthchecks, named network
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
      target: runner
    ports:
      - "${API_PORT:-3000}:3000"
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:16-alpine
    volumes:
      - pg_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME}
    networks:
      - app-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASS}
    volumes:
      - redis_data:/data
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

volumes:
  pg_data:
  redis_data:

networks:
  app-network:
    driver: bridge
```

```yaml
# ❌ ERRADO — sem healthcheck, sem network, credentials inline
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: "postgresql://admin:senha123@db:5432/mydb" # HARDCODED!
  db:
    image: postgres
    environment:
      POSTGRES_PASSWORD: senha123 # HARDCODED!
    # Sem healthcheck — api pode subir antes do db!
```

### 3.2 depends_on com condition

```yaml
# ✅ CERTO — esperar db estar healthy antes de subir api
depends_on:
  db:
    condition: service_healthy

# ❌ ERRADO — depends_on sem condition (só espera container iniciar)
depends_on:
  - db   # Container subiu mas PostgreSQL ainda inicializando!
```

## 4. Volumes — Dogmas

- **Named volumes** para dados persistentes (DB, Redis, uploads).
- **Bind mounts** apenas em dev (`./src:/app/src`).
- Nunca usar bind mount para `node_modules` (conflito de plataforma).

```yaml
# ✅ CERTO — dev override com bind mount para hot-reload
# docker-compose.override.yml (apenas dev)
services:
  api:
    build:
      target: builder # Use builder stage em dev
    volumes:
      - ./src:/app/src # Hot reload
      - /app/node_modules # Anonymous volume (protege node_modules)
    command: npm run dev
```

## 5. Environment Variables

```yaml
# ✅ CERTO — referência a .env, nunca inline
services:
  api:
    env_file: .env
    environment:
      NODE_ENV: production
      PORT: ${API_PORT:-3000}  # Default value

# ❌ ERRADO — secrets inline
services:
  api:
    environment:
      DATABASE_URL: "postgresql://user:p@ss@db:5432/app"
      JWT_SECRET: "my-super-secret-key"  # Commitado no repo!
```

## 6. Produção — Checklist

- [ ] Multi-stage build (imagem final < 200MB)
- [ ] Non-root user (`USER appuser`)
- [ ] Healthcheck em TODOS os services
- [ ] Named volumes para dados persistentes
- [ ] `.dockerignore` atualizado
- [ ] `restart: unless-stopped` em prod
- [ ] Networks nomeadas para isolamento
- [ ] Secrets via `.env` (não commitado) ou Docker secrets
- [ ] `depends_on` com `condition: service_healthy`
- [ ] Logging driver configurado (json-file com max-size)
