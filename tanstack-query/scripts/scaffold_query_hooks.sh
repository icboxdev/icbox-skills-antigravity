#!/bin/bash
# Scaffold TanStack Query Hooks with Axios
if [ -z "$1" ]; then
    echo "Uso: $0 <EntityNamePascalCase>"
    echo "Exemplo: $0 Transaction"
    exit 1
fi
ENTITY=$1
ENTITY_LOWER=$(echo "$ENTITY" | tr '[:upper:]' '[:lower:]')
FILE="src/hooks/use${ENTITY}.ts"

echo "⚛️ Scaffolding TanStack Hooks: $ENTITY"
mkdir -p "src/hooks"

cat <<EOF > "$FILE"
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
// Ajuste o import do seu client de API (Axios/Fetch)
// import { api } from '@/lib/api'; 
const api = { get: async (u: string) => ({ data: [] }), post: async (u: string, d: any) => ({ data: d }) }; // Mock fallback

export const ${ENTITY_LOWER}Keys = {
  all: ['${ENTITY_LOWER}s'] as const,
  lists: () => [...${ENTITY_LOWER}Keys.all, 'list'] as const,
  details: () => [...${ENTITY_LOWER}Keys.all, 'detail'] as const,
  detail: (id: string) => [...${ENTITY_LOWER}Keys.details(), id] as const,
};

export function useGet${ENTITY}s() {
  return useQuery({
    queryKey: ${ENTITY_LOWER}Keys.lists(),
    queryFn: async () => {
      const { data } = await api.get('/${ENTITY_LOWER}s');
      return data;
    },
  });
}

export function useCreate${ENTITY}() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: any) => {
      const { data } = await api.post('/${ENTITY_LOWER}s', payload);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ${ENTITY_LOWER}Keys.lists() });
    },
  });
}
EOF
echo "✅ TanStack Query: React Hooks de Cache p/ $ENTITY ejetados."
