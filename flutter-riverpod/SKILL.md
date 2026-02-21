---
name: Flutter + Riverpod/BLoC
description: Validate, generate, and architect Flutter applications using Riverpod for state management, Sound Null Safety, and clean separation of concerns. Enforces typed providers, immutable state, and widget composition best practices.
---

# Flutter + Riverpod — Diretrizes Sênior

## 1. Zero-Trust & Limites de Contexto

- **Antes de gerar qualquer feature**, externalize a arquitetura proposta em um artefato (`AI.md` ou `/brain/`).
- Faça **micro-commits**: edite um widget/provider por vez, nunca reescreva árvores de widgets inteiras.
- Após concluir uma feature, **finalize a task** explicitamente para liberar contexto.
- **Sound Null Safety** é inegociável — nunca use `!` sem checar `null` antes.

## 2. Estrutura de Projeto Obrigatória

```
lib/
├── main.dart
├── app.dart                 # MaterialApp + ProviderScope
├── core/
│   ├── constants/
│   ├── theme/
│   ├── router/              # GoRouter ou AutoRoute
│   └── utils/
├── features/
│   └── auth/
│       ├── data/
│       │   ├── repositories/  # Implementações
│       │   └── sources/       # Remote/Local data sources
│       ├── domain/
│       │   ├── models/        # Entidades imutáveis
│       │   └── repositories/  # Abstrações (interfaces)
│       └── presentation/
│           ├── providers/     # Riverpod providers
│           ├── screens/       # Páginas
│           └── widgets/       # Componentes reutilizáveis
└── shared/
    ├── providers/             # Providers globais (auth, dio)
    └── widgets/               # Widgets genéricos
```

## 3. Riverpod — Dogmas

### 3.1 Usar `riverpod_generator` com tipagem forte

```dart
// ✅ CERTO — code generation, tipado, testável
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<AuthState> build() async {
    final repo = ref.watch(authRepositoryProvider);
    return repo.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email, password),
    );
  }
}

// ❌ ERRADO — StateNotifier manual, sem generator
class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  AuthNotifier() : super(const AsyncLoading()) {
    _init();
  }
  void _init() { /* acoplado, difícil de testar */ }
}
```

### 3.2 `ref.watch` vs `ref.read` — Regra de Ouro

```dart
// ✅ CERTO — watch no build (reativo), read em callbacks (imperativo)
class UserScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);  // REATIVO — rebuilda quando muda

    return ElevatedButton(
      onPressed: () => ref.read(authProvider.notifier).logout(),  // IMPERATIVO
      child: Text('Logout'),
    );
  }
}

// ❌ ERRADO — read no build (não reativo), watch em callback (warning)
Widget build(BuildContext context, WidgetRef ref) {
  final user = ref.read(userProvider);          // Nunca atualiza!
  return ElevatedButton(
    onPressed: () => ref.watch(authProvider),   // Cria subscription desnecessária
    child: Text('Logout'),
  );
}
```

### 3.3 `ref.listen` para side-effects

```dart
// ✅ CERTO — listen para navegação, snackbar, etc
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.listen(authProvider, (prev, next) {
    next.whenOrNull(
      error: (e, _) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e'))),
    );
  });
  // ...
}

// ❌ ERRADO — side-effects dentro do build sem listen
@override
Widget build(BuildContext context, WidgetRef ref) {
  final auth = ref.watch(authProvider);
  if (auth.hasError) {
    Navigator.pop(context);  // CRASHA por ser chamado durante build
  }
}
```

## 4. State — Sempre Imutável

```dart
// ✅ CERTO — freezed para imutabilidade + copyWith
@freezed
class UserState with _$UserState {
  const factory UserState({
    required String name,
    required String email,
    @Default(false) bool isLoading,
    String? errorMessage,
  }) = _UserState;
}

// ❌ ERRADO — mutação direta de objeto
class UserState {
  String name;  // Mutável — causa bugs de reatividade
  String email;
}
```

## 5. Widgets — Composição sobre Herança

- Breakar widgets em **componentes pequenos** (`const` quando possível).
- Nunca criar widgets > 100 linhas de `build()`.
- Usar `const` constructors agressivamente para evitar rebuilds.

```dart
// ✅ CERTO — widget granular, const
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.url, this.radius = 24});
  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
}

// ❌ ERRADO — avatar inline no build de uma tela gigante
// Nunca embede UI complexa diretamente no build da Screen
```

## 6. Performance

- **ListView.builder** para listas longas (nunca `Column` + `map`).
- **const** em tudo que for estático.
- `AutoDispose` nos providers (padrão com `riverpod_generator`).
- **Evite `setState` desnecessário** — use Riverpod ao invés de StatefulWidget.
- `RepaintBoundary` para isolar repaintings pesados.

## 7. Testes

```dart
// Provider override para testes
final container = ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(MockAuthRepository()),
  ],
);

final authState = await container.read(authProvider.future);
expect(authState, isA<AuthState>());
```

## 8. Segurança

- Secrets via `flutter_dotenv` ou `--dart-define`. Nunca hardcode.
- Validar todos os inputs de formulário no client E no server.
- Sanitizar deep links e parâmetros de rota.
- Certificate pinning em produção para APIs críticas.
