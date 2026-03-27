#!/bin/bash
# Generate High Availability Docker Compose
FILE="docker-compose.yml"
if [ -f "$FILE" ]; then 
    echo "O arquivo docker-compose.yml já existe nesta raiz!"; 
    exit 1; 
fi

echo "🐋 Scaffolding HA Docker-Compose..."
cat <<EOF > "$FILE"
version: '3.8'

services:
  app:
    build: .
    restart: unless-stopped
    ports:
      - "\${SERVER_PORT:-3333}:\${SERVER_PORT:-3333}"
    environment:
      - DATABASE_URL=\${DATABASE_URL}
      - REDIS_URL=\${REDIS_URL}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - internal
      - edge

  db:
    image: postgres:16-alpine
    restart: always
    environment:
      POSTGRES_USER: \${DB_USER:-postgres}
      POSTGRES_PASSWORD: \${DB_PASS:-postgres}
      POSTGRES_DB: \${DB_NAME:-app}
    ports:
      - "5432:5432"
    volumes:
      - db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \${DB_USER:-postgres}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - internal

  redis:
    image: redis:7-alpine
    restart: always
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - internal

volumes:
  db_data:
  redis_data:

networks:
  internal:
    driver: bridge
  edge:
    driver: bridge
EOF
echo "✅ DevOps: docker-compose.yml blindado gerado com sucesso."
