---
name: WebSockets & SSE Realtime Scaling
description: Architect, scale, and validate real-time server-push systems using WebSockets, Server-Sent Events (SSE), and Redis Pub/Sub backplanes. Resolves connection limits, sticky session anti-patterns, and horizontal scaling.
---

# WebSockets & SSE Realtime Scaling Architecture

This skill dictates the dogmas for deploying bidirectional (WebSockets) or unidirectional (SSE) live data streams, scaling them across multi-node server deployments.

## 🏛️ Architectural Dogmas

1.  **Choose the Right Protocol**:
    *   **SSE (Server-Sent Events)**: Use for Unidirectional Server-to-Client flows (e.g., Live Dashboards, Stock Tickers, Notification feeds). SSE flows over standard HTTP/1.1 or HTTP/2, easily crosses firewalls, and reconnects automatically.
    *   **WebSockets (WS)**: Use for Bidirectional, Low-Latency flows (e.g., Live Chat, Collaborative Editing, Gaming). 
2.  **Stateless Tiers via Pub/Sub Backplane**: WebSockets are inherently stateful (TCP pinned to one server). To scale horizontally, the nodes MUST be joined by a Redis Pub/Sub (or Kafka) backplane. When Node A wants to message Client X connected to Node B, Node A publishes to Redis, Node B subscribes and relays to Client X.
3.  **Avoid Sticky Sessions**: Do not use sticky sessions in your Load Balancer for WebSockets. The Pub/Sub backplane removes the need for this, allowing the LB to perfectly distribute connections.
4.  **No Message Persistence in Pub/Sub**: Redis Pub/Sub is fire-and-forget. If a client reconnects after a drop, they will miss messages. The architecture MUST include a REST API to fetch "missed history," or use Redis Streams/Kafka if absolute message ordering and persistence are required.

## 💻 Implementation Patterns

### CERTO: Redis Pub/Sub Backplane (Node.js/Socket.io example)
```javascript
// CERTO: Using Redis to scale WebSocket nodes horizontally
import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { createClient } from 'redis';

const io = new Server(server);

// 1. Create Pub and Sub Redis Clients
const pubClient = createClient({ url: process.env.REDIS_URL });
const subClient = pubClient.duplicate();

await Promise.all([pubClient.connect(), subClient.connect()]);

// 2. Attach the Redis Adapter
// This automatically bridges broadcast events across all running Node.js instances
io.adapter(createAdapter(pubClient, subClient));

io.on('connection', (socket) => {
  socket.on('chat_message', (msg) => {
    // ✅ This will reach users connected to OTHER load-balanced servers
    // because the Redis Adapter publishes it to the Redis backplane.
    io.emit('chat_message', msg); 
  });
});
```

### ERRADO: Single Node Bottleneck
```javascript
// ERRADO: Emitting directly on a basic instance.
// ❌ Fails as soon as a second server is spawned. User A (Server 1) won't see User B (Server 2).
const io = new Server(server);
io.on('connection', (socket) => {
  socket.on('msg', (data) => {
    io.emit('msg', data); 
  });
});
```

## 🔥 Handling Scale and Connections

- **Connection Limits (ulimit)**: Linux limits open file descriptors (connections) per process to 1024 by default. For WebSocket servers, this OS limit MUST be raised (`ulimit -n 65535`).
- **Memory per Connection**: Every TCP connection consumes RAM. Optimize the socket object footprint.
- **Heartbeats & Ping/Pong**: To detect broken connections (e.g., user went into a tunnel), the server MUST implement periodic Ping/Pong frames to clean up dead sockets and free memory.
- **Connection Storms**: If the server restarts, 100,000 clients will reconnect simultaneously. Use a randomized jitter delay on the client-side reconnection logic to prevent a DDoS sequence.
