#!/bin/bash
# Scaffold Vue3 PrimeVue CRUD View
if [ -z "$1" ]; then
    echo "Uso: $0 <EntityNamePascalCase> <rota-kebab>"
    echo "Exemplo: $0 UserProfile user-profile"
    exit 1
fi
ENTITY=$1
KEBAB=$2
DIR="src/views/$KEBAB"
FILE="$DIR/${ENTITY}View.vue"

echo "🟢 Scaffolding Vue 3 PrimeVue CRUD: $ENTITY"
mkdir -p "$DIR/components"

cat <<EOF > "$FILE"
<script setup lang="ts">
import { ref } from 'vue';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import Dialog from 'primevue/dialog';

const items = ref([]);
const isDialogVisible = ref(false);

const openDialog = () => {
  isDialogVisible.value = true;
};
</script>

<template>
  <div class="flex flex-col gap-6 p-6">
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-surface-900 dark:text-surface-0">Gerenciar ${ENTITY}</h1>
        <p class="text-surface-500 dark:text-surface-400">Listagem e cadastro.</p>
      </div>
      <Button label="Novo Registro" icon="pi pi-plus" @click="openDialog" />
    </div>

    <!-- Data Table via PrimeVue -->
    <div class="card">
      <DataTable :value="items" showGridlines stripedRows emptyMessage="Nenhum registro encontrado.">
        <Column field="id" header="Identificador" />
        <!-- TODO: Add more columns -->
      </DataTable>
    </div>

    <!-- Create/Edit Form Dialog -->
    <Dialog v-model:visible="isDialogVisible" modal header="Criar ${ENTITY}" :style="{ width: '50vw' }">
      <p class="m-0">
        <!-- Form Fields Go Here -->
        Formulário pendente de implementação.
      </p>
    </Dialog>
  </div>
</template>
EOF
echo "✅ Vue 3: View Base PrimeVue (DataTable + Dialog) instanciada."
