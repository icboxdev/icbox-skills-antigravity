---
name: GraphQL Apollo Federation (Supergraph)
description: Architect, generate, and validate GraphQL Federation utilizing Apollo Supergraph, Apollo Router (Rust), and Subgraph schema design. Enforces static composition, DataLoaders for N+1 mitigation, and schema registry workflows.
---

# GraphQL Apollo Federation Engineering

This skill dictates the architectural dogmas for building distributed, scalable GraphQL APIs using the Apollo Federation (Supergraph) pattern.

## 🏛️ Architectural Dogmas

1.  **Supergraph vs. Subgraph**: NEVER build a single monolithic GraphQL server for complex domains. Divide domains into independent **Subgraphs** (e.g., Users, Inventory, Orders). A central gateway composes these into a single **Supergraph** exposed to clients.
2.  **Apollo Router (Rust)**: ALWAYS deploy the Apollo Router (written in Rust) as the central entry point, rather than the deprecated Node.js `apollo-gateway`. The Router provides magnitudes better latency and CPU efficiency.
3.  **Static Composition (CI/CD)**: Do NOT compose the Supergraph schema at runtime. Use the Rover CLI in the CI/CD pipeline to validate and statically compose subgraphs into a single schema artifact (`supergraph.graphql`). This prevents runtime crashes due to incompatible subgraph deployments.
4.  **Dataloaders for N+1**: Every subgraph MUST implement the DataLoader pattern (batching and caching) for resolving nested entities or `@key` references. Failing to do so in a federated graph causes exponential N+1 query explosions.
5.  **Entities and `@key`**: Define shared types as Entities using the `@key` directive. This allows one subgraph to extend a type defined in another without strong coupling.

## 💻 Implementation Patterns

### CERTO: Defining a Subgraph Entity (Inventory)
```graphql
# Subgraph: Inventory
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.3", import: ["@key", "@external"])

# The Product type is owned by the Products subgraph, but we extend it here.
type Product @key(fields: "id") {
  id: ID!
  inStock: Boolean!
  shippingEstimate: Int
}
```

### CERTO: DataLoader for Entity Reference Resolution (Node.js/Apollo)
```javascript
// Resolving the federated reference using a DataLoader to prevent N+1
const resolvers = {
  Product: {
    // __resolveReference is called by the Router when fetching fields for this entity
    __resolveReference: async (productRef, context) => {
      // ✅ CERTO: Uses DataLoader to batch fetch products in a single DB query
      return await context.dataLoaders.inventoryLoader.load(productRef.id);
    }
  }
};
```

### ERRADO: Anti-Patterns
```javascript
const resolvers = {
  Product: {
    __resolveReference: async (productRef, context) => {
      // ❌ ERRADO: Querying DB directly inside the resolver creates catastrophic N+1
      // If the Router asks for 50 products, this triggers 50 separate SQL queries.
      return await db.query('SELECT * FROM inventory WHERE product_id = ?', [productRef.id]);
    }
  }
};
```

## 🧠 Federation v2 Best Practices (2024-2025)

- **Value Types vs. Entities**: Only use `@key` (Entities) for types that genuinely need to cross subgraph boundaries and be extended. For simple objects returned by one subgraph, use standard GraphQL types (Value Types).
- **Client-Side GraphQL Requirements**: Clients should NEVER point directly to a subgraph. They must only communicate with the Apollo Router.
- **Monitoring**: Inject OpenTelemetry tracing into the Apollo Router to track latency across the subgraphs during distributed query execution.
