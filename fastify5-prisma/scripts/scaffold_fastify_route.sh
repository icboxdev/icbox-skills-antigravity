#!/bin/bash
# Scaffold Fastify Route + Zod + Controller
if [ -z "$1" ]; then
    echo "Uso: $0 <nomedorecurso_snake_case> <NomeDoRecursoPascalCase>"
    echo "Exemplo: $0 user_profile UserProfile"
    exit 1
fi
RES_LOWER=$1
RES_PASCAL=$2
DIR="src/modules/$RES_LOWER"

echo "⚡ Scaffolding Fastify5 module: $RES_PASCAL"
mkdir -p "$DIR"

# Schema
cat <<EOF > "$DIR/${RES_LOWER}.schema.ts"
import { z } from 'zod';

export const create${RES_PASCAL}Schema = z.object({
  // TODO: Add strict validations
});

export type Create${RES_PASCAL}Input = z.infer<typeof create${RES_PASCAL}Schema>;
EOF

# Controller
cat <<EOF > "$DIR/${RES_LOWER}.controller.ts"
import { FastifyReply, FastifyRequest } from 'fastify';
import { create${RES_PASCAL}Schema } from './${RES_LOWER}.schema';
import { prisma } from '../../lib/prisma'; // Adjust your prisma import

export async function create${RES_PASCAL}Handler(
  request: FastifyRequest,
  reply: FastifyReply
) {
  const data = create${RES_PASCAL}Schema.parse(request.body);
  
  // TODO: Business logic via Service
  // const result = await create${RES_PASCAL}Service(data);
  const result = { id: crypto.randomUUID(), ...data };

  return reply.status(201).send({ data: result });
}
EOF

# Route
cat <<EOF > "$DIR/${RES_LOWER}.route.ts"
import { FastifyInstance } from 'fastify';
import { create${RES_PASCAL}Handler } from './${RES_LOWER}.controller';

export async function ${RES_LOWER}Routes(fastify: FastifyInstance) {
  fastify.post('/', create${RES_PASCAL}Handler);
  
  // TODO: Define GET, PUT, DELETE
}
EOF
echo "✅ Fastify5: Route, Controller and Schema generated for $RES_LOWER."
