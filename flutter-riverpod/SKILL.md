---
name: Flutter + Riverpod/BLoC
description: Validate, generate, and architect Flutter applications using Riverpod for state management, Sound Null Safety, and clean separation of concerns. Enforces typed providers, immutable state, feature-first structure, and widget composition best practices.
---

# 🦋 Flutter + Riverpod Architecture & Mastery

This skill defines the architectural dogmas and absolute best practices for building scalable, maintainable, and high-performance cross-platform applications using **Flutter** and **Riverpod** (or BLoC) following Clean Architecture principles.

## 🏛️ Architectural Dogmas (Clean Architecture)

Your Flutter applications MUST be strictly divided into three distinct layers, ensuring a unidirectional flow of dependencies (inward-pointing):

1.  **Domain Layer (Core):**
    *   **Dogma:** MUST be pure Dart. Zero dependencies on Flutter UI frameworks (`package:flutter/material.dart`, etc.) or third-party libraries (except maybe Equatable/Freezed).
    *   **Contents:** Entities (plain Dart classes), Repository Interfaces (Contracts), and Use Cases (Business Logic).
    *   **Rule:** Use cases must be small, single-responsibility classes.

2.  **Data Layer (Infrastructure):**
    *   **Dogma:** Implements the Domain repository interfaces. Communicates with external APIs, local databases (Isar/Hive/SQLite), and handles data serialization.
    *   **Contents:** Repository Implementations, Data Sources (Remote/Local), and DTOs/Models (with `json_serializable` or `freezed`).
    *   **Rule:** Data mappers MUST exist here to translate DTOs into pure Domain Entities before returning them to the Domain/Presentation layers.

3.  **Presentation Layer (UI):**
    *   **Dogma:** Contains Flutter Widgets and State Management (Riverpod Providers).
    *   **Rule:** Widgets MUST be dumb. They only listen to state (via `ref.watch`) and dispatch events to Providers. They NEVER contain business logic or make direct API calls.

**Directory Structure (Feature-First):**
```text
lib/
├── src/
│   ├── features/
│   │   ├── authentication/
│   │   │   ├── data/          # Repositories, Data Sources
│   │   │   ├── domain/        # Entities, Use Cases
│   │   │   └── presentation/  # Widgets, Controllers, Providers
│   │   └── products/
│   └── routing/             # go_router configuration
```

## 💧 State Management with Riverpod

Riverpod is the state management and Dependency Injection (DI) framework of choice. It is context-free, compile-safe, and highly testable.

### 1. `AsyncValue` for Asynchronous Operations
Never manually track `isLoading` or `hasError` booleans. Always use `AsyncValue` (via `FutureProvider` or `AsyncNotifierProvider`) and its `.when()` method for UI rendering.

```dart
// CERTO: Using AsyncValue and Riverpod 2.0+ Notifiers
@riverpod
class ProductList extends _$ProductList {
  @override
  Future<List<Product>> build() async {
    return ref.read(productRepositoryProvider).getProducts();
  }
}

// In Widget:
final productState = ref.watch(productListProvider);
return productState.when(
  data: (products) => ProductListView(products: products),
  loading: () => const CircularProgressIndicator(),
  error: (error, stack) => ErrorWidget(error),
);
```

### 2. Dependency Injection via Providers
Use Providers to inject Repositories and Use Cases. This enables trivial mocking during tests.

```dart
// CERTO: DI Pattern with Riverpod
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Can be swapped out in testing via ProviderScope overrides
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});
```

### 3. Immutable State
State managed by Riverpod MUST be strictly immutable. Use the `freezed` package to generate immutable data classes with `copyWith` and equality operators.

```dart
// CERTO: Freezed state class
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.loading() = _Loading;
  const factory AuthState.authenticated(User user) = _Authenticated;
  const factory AuthState.error(String message) = _Error;
}
```

## 🚨 Anti-Patterns & Constraints (DO NOT DO THIS)

*   ❌ **NEVER** use `StatefulWidget` for complex business logic. Use `ConsumerWidget` + Riverpod Notifiers. Use `StatefulWidget` ONLY for transient UI state (like scroll controllers or animations).
*   ❌ **NEVER** pass `BuildContext` into Repositories, Domain logic, or Riverpod Providers. State MUST be context-agnostic.
*   ❌ **NEVER** perform direct HTTP calls inside a UI Widget.
*   ❌ **NEVER** mutate state objects directly. Always emit a new instance (e.g., via `state = state.copyWith(...)`).
*   ❌ **NEVER** nest features inside layers. (i.e., do not use `lib/presentation/auth`, `lib/domain/auth`. USE `lib/features/auth/presentation`, etc.).

## 🧪 Testing Strategy
*   **Unit Tests:** Test Use Cases and Repositories in isolation. Since the Domain layer is pure Dart, these tests execute instantaneously.
*   **Provider Tests:** Create a test `ProviderContainer` to verify StateNotifier/AsyncNotifier behavior without a UI.
*   **Widget Tests:** Override dependencies at the root:
    ```dart
    ProviderScope(
      overrides: [
        productRepositoryProvider.overrideWithValue(MockProductRepository()),
      ],
      child: MyApp(),
    )
    ```

## 🧭 Routing
Use `go_router` for declarative, URL-based routing. Integrate it with Riverpod so that authentication state changes automatically redirect the user (e.g., kicking them to the login screen if the token expires).
