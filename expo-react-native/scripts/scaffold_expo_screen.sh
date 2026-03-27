#!/bin/bash
# Scaffold Expo Router Screen + NativeWind
if [ -z "$1" ]; then
    echo "Uso: $0 <screen-route-name>"
    echo "Exemplo: $0 profile"
    exit 1
fi
SCREEN=$1
FILE="app/(tabs)/$SCREEN.tsx"

echo "📱 Scaffolding Expo Screen: $SCREEN"
mkdir -p "app/(tabs)"

cat <<EOF > "$FILE"
import { View, Text } from 'react-native';
// import { Stack } from 'expo-router'; // Only if not in tab

export default function ${SCREEN^}Screen() {
  return (
    <View className="flex-1 bg-zinc-950 items-center justify-center">
      {/* <Stack.Screen options={{ title: '${SCREEN^}' }} /> */}
      
      <Text className="text-zinc-100 font-bold text-2xl font-geist">
        ${SCREEN^}
      </Text>
      <Text className="text-zinc-400 mt-2">
        Tela gerada via Antigravity SSJ.
      </Text>
    </View>
  );
}
EOF
echo "✅ Mobile: Tela $SCREEN adicionada ao Expo Router com tipagem NativeWind."
