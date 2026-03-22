# Architecture Standards

## Rules
- Backend: Route/Controller -> Service -> Repository -> Database
- Frontend: Component-based with shared design tokens
- APIs: OpenAPI 3.1 spec first, then implement, then test against spec
- Validation: Zod (TypeScript), Pydantic (Python) at system boundaries
- All API responses use a standard envelope: `{ success, data, error, meta }`

## Examples
```
src/
  routes/       # HTTP handlers — thin, delegate to services
  services/     # Business logic — testable, no HTTP awareness
  repositories/ # Database queries — one per entity
  middleware/   # Auth, validation, error handling
  types/        # Shared TypeScript types / interfaces
```

## Event-Driven Patterns
- Use message queues (BullMQ, SQS, RabbitMQ) for async work: email, notifications, heavy processing
- Event flow: Route → Service → emit event → Queue → Worker → Service
- Workers follow the same Service → Repository pattern as routes
- Idempotent handlers: every event handler must be safe to retry
- Dead letter queues for failed events — never silently drop messages

## Anti-Patterns
- Putting business logic in route handlers — use the service layer
- Accessing the database directly from routes — use repositories
- Skipping the OpenAPI spec — spec is the contract, code implements it
- Synchronous processing for heavy work — use a queue
- Non-idempotent event handlers — always design for at-least-once delivery
