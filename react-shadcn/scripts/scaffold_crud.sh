#!/bin/bash
# Scaffold React Shadcn CRUD Page
# Usage: ./scaffold_crud.sh <EntityNamePascal> <entity-route-kebab>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Erro: Faltam argumentos."
    echo "Uso: $0 <EntityNamePascalCase> <entity-kebab-case>"
    echo "Exemplo: $0 UserProfile user-profile"
    exit 1
fi

ENTITY_PASCAL=$1
ENTITY_KEBAB=$2
TARGET_DIR="src/app/(dashboard)/$ENTITY_KEBAB"

echo "🎨 Scaffolding React CRUD Page: $ENTITY_PASCAL em $TARGET_DIR..."

mkdir -p "$TARGET_DIR/components"

# page.tsx
cat <<EOF > "$TARGET_DIR/page.tsx"
import { PageHeader } from "@/components/shared/PageHeader";
import { ${ENTITY_PASCAL}DataTable } from "./components/${ENTITY_PASCAL}DataTable";
import { ${ENTITY_PASCAL}CrudDrawer } from "./components/${ENTITY_PASCAL}CrudDrawer";

export default function ${ENTITY_PASCAL}Page() {
  return (
    <div className="flex flex-col gap-6 p-6 fade-in font-geist">
      <PageHeader 
        title="${ENTITY_PASCAL}s" 
        description="Gerenciamento de base de ${ENTITY_PASCAL}s."
        action={<${ENTITY_PASCAL}CrudDrawer mode="create" />}
      />
      
      {/* 
        Dogma: Toda listagem deve usar DataTable. 
        NUNCA crie tabela HTML manual. 
      */}
      <${ENTITY_PASCAL}DataTable />
    </div>
  );
}
EOF

# DataTable Placeholder
cat <<EOF > "$TARGET_DIR/components/${ENTITY_PASCAL}DataTable.tsx"
'use client';

export function ${ENTITY_PASCAL}DataTable() {
  return (
    <div className="rounded-md border border-neutral-800 bg-neutral-900/50 p-4">
      {/* Renderize sua DataTable aqui importando de @/components/ui/data-table */}
      <span className="text-sm text-neutral-400">Tabela de $ENTITY_PASCAL pendente de hidratação...</span>
    </div>
  );
}
EOF

# CrudDrawer Placeholder
cat <<EOF > "$TARGET_DIR/components/${ENTITY_PASCAL}CrudDrawer.tsx"
'use client';

import { useState } from "react";
// Importar componentes do Shadcn/Radix (Sheet, Button) aqui

export function ${ENTITY_PASCAL}CrudDrawer({ mode }: { mode: 'create' | 'edit', initialData?: any }) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button 
        onClick={() => setOpen(true)}
        className="bg-sky-500 hover:bg-cyan-400 font-medium px-4 py-2 rounded text-white transition-all transform active:scale-95"
      >
        {mode === 'create' ? 'Novo Registro' : 'Editar'}
      </button>

      {/* Sheet component go here */}
      {open && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm">
           <div className="fixed right-0 h-full w-[400px] border-l border-neutral-800 bg-[#0C0C0E] p-6 slide-in-from-right">
              <h2 className="text-xl font-geist font-semibold text-white mb-6">
                 {mode === 'create' ? 'Criar ${ENTITY_PASCAL}' : 'Editar ${ENTITY_PASCAL}'}
              </h2>
              {/* React Hook Form + Zod Form go here */}
              <button onClick={() => setOpen(false)} className="text-neutral-400 mt-4">Fechar</button>
           </div>
        </div>
      )}
    </>
  );
}
EOF

echo "✅ Página CRUD de $ENTITY_PASCAL ancorada com os dogmas do Design System."
