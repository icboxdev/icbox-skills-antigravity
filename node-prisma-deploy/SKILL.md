---
name: Node.js Prisma Deploy (Coolify)
description: Architect, validate, and generate Node.js + Prisma backend deployments tailored for Coolify. Enforces multi-stage Docker builds, Debian Slim over Alpine for Prisma C++ binaries compatibility, security boundaries, and strict build ordering.
---

# Node.js + Prisma Deployment Architecture

Esta skill define os dogmas e as melhores práticas exclusivas para criação e orquestração de deploys conteinerizados (Docker) de backends em Node.js usando o Prisma ORM, voltados especificamente para plataformas de PaaS como Coolify.

## Princípios Básicos (Zero-Trust)

- **O Prisma possui binários pesados de C++ (Query Engine).** Nunca assuma que a imagem de contêiner tem as bibliotecas de sistema necessárias prontas.
- **O Build é sagrado.** Se o Prisma não for capaz de deduzir o schema antes da compilação, o TypeScript falhará reclamando de tipos inexistentes ou `any`.
- Aplicações na nuvem operam sob o usuário `root` por padrão no Docker, o que é um risco de segurança inaceitável (Privilege Escalation).

## Dogmas Arquiteturais (A lei)

### 1. Alpine Linux vs Debian Slim

❌ **NUNCA** utilize `node:<version>-alpine` quando trabalhar com Prima ORM em produção, a menos que saiba contornar explicitamente os conflitos do pacote `musl` contra a glibc convencional.
✅ **SEMPRE** utilize `node:<version>-slim` (baseado em Debian). A libc do Debian já possui extrema afinidade com os binários do Prisma sem requerer dezenas de hacks ou "binaryTargets" extensos.

### 2. A Necessidade Absoluta do OpenSSL

O Prisma Engine comunica com o banco usando túneis seguros implementados via bibliotecas nativas do OpenSSL.
✅ **SEMPRE** instale pacotes nativos de C++ `openssl` e `curl` (para healthcheck) em **AMBOS** os estágios do multi-stage build (Builder e Production). O construtor falhará o empacotamento do Prisma Engine (Panda) se não encontrar a assinatura do libssl nativo.

### 3. Ordem Rigorosa de Execução (Build Flow)

✅ O `npm ci` falhará não-intencionalmente se o contêiner de build herdar um ambiente injetado externamente como `NODE_ENV=production` (o CI não baixará `tsc`, `typescript`, `@types/node`).

- Force `ENV NODE_ENV=development` na subetapa de `builder`.
- Execute a geração de tipos **antes** do build da aplicação para prever a DTO e checagem de tipos estática na fase seguinte do compilador TypeScript: `npx prisma generate` -> `npm run build`.

### 4. Permissões de Artefatos no Runtime (Non-Root User)

Impedir vulnerabilidades requer reverter a propriedade dos executáveis na fase final do Dockerfile.
✅ Crie um non-root user (`appuser` e `appgroup`) e aplique `chown -R appuser:appgroup /app` após a cópia mult-stage dos artefatos.

## Snippets Essenciais (Few-Shot Prompting)

### CERTO: O Dockerfile Supremo (Coolify Ready)

```dockerfile
# ─── Stage 1: Build ───────────────────────────────────────────────────────────
FROM node:22-slim AS builder

WORKDIR /app

# Forçar development para instalar devDependencies (nest, typescript, tsc, etc)
ENV NODE_ENV=development

# Instalar OpenSSL imediatamente (necessário para gerar as Engines C++ locais)
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

COPY package*.json ./
RUN npm ci

# Copia configurações vitais e fontes
COPY tsconfig*.json ./
COPY prisma ./prisma
COPY src ./src

# GERA TIPOS primeiro (para hidratar os .d.ts baseados no banco)
RUN npx prisma generate

# COMPILA O TS depois
RUN npm run build

# ─── Stage 2: Production ──────────────────────────────────────────────────────
FROM node:22-slim AS production

ENV NODE_ENV=production

WORKDIR /app

# Instala ferramentas base (openssl pro prisma conectar; curl pro healthcheck)
RUN apt-get update -y && apt-get install -y openssl curl && rm -rf /var/lib/apt/lists/*

# Configuração de usuário não-root segura (Debian format)
RUN groupadd -g 1001 appgroup && \
  useradd -u 1001 -g appgroup -m appuser

# Instala e purga (foco apenas em manter dependências da production-only)
COPY package*.json ./
RUN npm ci --omit=dev

# Copia bibliotecas binárias, definições geradas e do build da raiz
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma/client ./node_modules/@prisma/client
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma

COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

# Aplica posse a tudo que foi copiado pelo Root
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

# Curl verificando HTTP Status sem wget
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health | grep -q '200' || exit 1

ENTRYPOINT ["/bin/sh", "docker-entrypoint.sh"]
```

### CERTO: docker-entrypoint.sh Minimalista

```bash
#!/bin/sh
set -e

echo "🔄 Rodando migrações do banco..."
npx prisma migrate deploy

# (Opcional) Seeders idempotentes aqui

echo "🚀 Iniciando servidor..."
# Fastify/Express/NestJS:
node dist/main.js
# Ou index.js a depender da compilação raiz
```

### ERRADO: Armadilhas no Deploy

```dockerfile
# ERRADO: Node Alpine causará crash "Prisma Client could not locate the Query Engine for runtime linux-musl-openssl"
FROM node:22-alpine

# ERRADO: Gerar prisma DEPOIS de compilar TS
RUN npm run build
RUN npx prisma generate

# ERRADO: Executar no ambiente ROOT sem chown e proteção EACCES
COPY --from=builder /app/dist ./dist
USER node

# ERRADO: Healthcheck com wget em alpine quebrado
HEALTHCHECK CMD wget -qO- http://localhost:3000 || exit 1
```

---

Quando aplicar esta skill, analise e integre perfeitamente este template de `Dockerfile` à raiz do novo backend em Node, alterando somente caminhos de outputs conforme a stack específica (como o `dist/src/main.js` no Nest ou apenas `dist/server.js` no Fastify).
