#!/bin/bash
# Generate Coolify Nixpacks Config
FILE="nixpacks.toml"
if [ -f "$FILE" ]; then 
    echo "O arquivo nixpacks.toml já existe nesta raiz!"; 
    exit 1; 
fi

echo "🌐 Scaffolding Coolify Nixpacks TOML..."

cat <<EOF > "$FILE"
[providers]
  node = true

[variables]
  NODE_ENV = "production"

[phases.setup]
  nixPkgs = ["...", "nodejs_20", "openssl"]

[phases.install]
  cmds = ["npm ci --include=dev"] # Ensure prisma CLI or build tools are available

[phases.build]
  cmds = ["npm run build"]

[phases.start]
  cmd = "npm run start"

# Dogma: If deploying Prisma, ensure binary compatibility using Debian slim or overriding Nixpacks C dependencies here.
EOF
echo "✅ DevOps: nixpacks.toml focado no ecossistema atual ejetado."
