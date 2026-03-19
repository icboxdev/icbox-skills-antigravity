---
name: Domain-Driven Design (DDD) & Clean Architecture
description: Architect and validate complex software systems enforcing Domain-Driven Design, Clean Architecture, CQRS, Bounded Contexts, and ubiquitous language boundaries.
---

# Domain-Driven Design (DDD) & Clean Architecture Mastery

This skill enforces enterprise-grade structural patterns for complex applications. It mandates the separation of concerns, rich domain models, and strict dependency rules where Domain logic is completely isolated from Infrastructure and Delivery mechanisms.

## ZERO-TRUST & ARCHITECTURAL RULES
*   **Domain is King:** The Domain layer MUST NOT depend on ORMs (Prisma, SQLx), web frameworks (Axum, Express), or external APIs. It contains pure business logic.
*   **Dependency Rule:** Dependencies MUST ALWAYS point inwards. `Presentation -> Application -> Domain <- Infrastructure`.
*   **No Anemic Domains:** Entities must encapsulate behavior (methods), not just state (getters/setters). State manipulation must pass through domain invariants.

## 1. Core Dogmas

### Bounded Contexts & Ubiquitous Language
*   A Bounded Context is a linguistic and architectural boundary. A "User" in the IAM context has attributes like `password_hash` and `roles`. A "User" (or "Customer") in the Billing context has `stripe_id` and `payment_methods`. DO NOT unify them into a monolithic God Object.
*   Use terms from the Ubiquitous Language in your code. If the business says "Dispatch an Order", your method should be `order.dispatch()`, NOT `updateOrderStatus(2)`.

### Aggregate Roots (AR)
*   An Aggregate is a transactional boundary. Updates to any entity within an aggregate MUST go through the Aggregate Root.
*   Aggregates reference other Aggregates by ID, NEVER by direct object reference.
*   A database transaction should rarely modify more than one Aggregate instance. If it must, consider eventual consistency via Domain Events.

### Value Objects
*   Concepts without conceptual identity that describe characteristics of a thing (e.g., `Money`, `EmailAddress`, `Coordinates`).
*   MUST be immutable. To change a value, create a new instance.
*   MUST encapsulate validation logic upon instantiation.

### CQRS (Command Query Responsibility Segregation)
*   **Commands:** Change state, do not return data (except maybe an ID or Result). Represented by distinct DTOs/structs (e.g., `CreateUserCommand`).
*   **Queries:** Return data, do not change state. Can bypass the Domain layer and read directly from the database (via Infrastructure) to optimize complex read projections.

## 2. Few-Shot Examples

### Rich Domain Model vs Anemic Domain Model

**❌ INCORRECT (Anemic Domain Model - Procedural Code)**
```typescript
class User {
  public id: string;
  public status: string;
  // Bad: Pure data bag, no encapsulation
}

class UserService {
  // Bad: Business logic leaked into the application service
  activateUser(user: User) {
    if (user.status === 'ACTIVE') throw new Error("Already active");
    user.status = 'ACTIVE';
    userRepository.save(user);
  }
}
```

**✅ CORRECT (Rich Domain Model - DDD)**
```typescript
class User { // Aggregate Root
  private id: string;
  private status: UserStatus; // Value Object

  // Good: Invariants enforced inside the domain entity
  public activate(): void {
    if (this.status.isActive()) {
      throw new DomainException("User is already active.");
    }
    this.status = UserStatus.ACTIVE;
    // this.addDomainEvent(new UserActivatedEvent(this.id));
  }
}

class UserApplicationService {
  activateUser(id: string) {
    const user = userRepository.findById(id); // Returns Domain Entity
    user.activate(); // Tell, don't ask
    userRepository.save(user);
  }
}
```

### Directory Structure (Clean Architecture)

**✅ CORRECT (Strict Layering)**
```text
src/
├── domain/               # Pure logic, no dependencies
│   ├── entities/         # Aggregate roots and local entities
│   ├── value_objects/    # Immutable typed objects
│   ├── events/           # Domain events
│   └── repositories/     # ONLY Interfaces/Traits
├── application/          # Use cases / Application Services
│   ├── commands/         # CQRS: State mutations
│   ├── queries/          # CQRS: Data reading
│   └── dtos/
├── infrastructure/       # Dirty details (DB, External APIs)
│   ├── database/         # Implementations of Domain Repositories (Prisma/SQLx)
│   ├── message_broker/   # Kafka/RabbitMQ publishers
│   └── services/         # External API adapters (Stripe, Asaas)
└── presentation/         # Delivery mechanism
    ├── controllers/      # REST API handlers (Axum / NestJS)
    └── middlewares/
```

## 3. Workflow

1.  **Analyze:** Listen to the business experts. Identify nouns (Entities/Value Objects) and verbs (Commands/Events).
2.  **Define Bounded Contexts:** Group related concepts. Define explicit contracts (APIs or Events) between contexts.
3.  **Model the Domain First:** Write the `domain/` folder without touching a database schema or web framework. Use Unit Tests to validate the rules.
4.  **Implement Adapters:** Build the Infrastructure layer to persist the Domain objects and the Application layer to orchestrate the use cases.
