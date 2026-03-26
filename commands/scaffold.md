---
name: scaffold
description: Generate a complete CRUD vertical slice from database schema to API routes to frontend components
---
Generate a full CRUD vertical slice: $ARGUMENTS

You are the Scaffolding Engine, executing the **Scaffold** workflow.

## Workflow Overview

**Goal:** Generate a complete CRUD vertical slice — from database schema to API routes to frontend components — for a given entity

**Input:** Entity name + fields (e.g., "Product: name:string, price:number, description:text, categoryId:uuid")

**Output:** All files needed for full CRUD operations on the entity

**Best for:** Rapid feature bootstrapping, consistent code generation, reducing boilerplate

---

## Step 1: Parse Entity Definition

Extract from the user's input:
- **Entity name** (singular): e.g., `Product`
- **Table name** (plural, snake_case): e.g., `products`
- **Fields** with types: `name:string`, `price:number`, `description:text`, `categoryId:uuid`
- **Relations** (if specified): `categoryId -> categories.id`

If the input is ambiguous, ask the user to clarify fields and types.

## Step 2: Detect Project Stack

Read project configuration to determine:

```bash
ls package.json pyproject.toml 2>/dev/null
```

Detect:
- **ORM/Database:** Prisma, Drizzle, SQLAlchemy, Django ORM, TypeORM
- **HTTP Framework:** Express, Fastify, Hono, NestJS, FastAPI, Django
- **Validation:** Zod, Pydantic, class-validator, Joi
- **Frontend:** React, Next.js, Vue, Svelte (if applicable)
- **Testing:** Vitest, Jest, Pytest

**Read existing code** to match patterns:
```bash
# Find existing model/schema examples
ls src/db/schema* src/models/* prisma/schema.prisma 2>/dev/null
# Find existing route examples
ls src/routes/* src/api/* src/controllers/* 2>/dev/null
# Find existing service examples
ls src/services/* src/lib/* 2>/dev/null
# Find existing test examples
ls src/**/*.test.* tests/* __tests__/* 2>/dev/null
```

**CRITICAL:** Read at least one existing example of each file type. Match the exact patterns, naming conventions, imports, and structure used in the project.

## Step 3: Generate Database Layer

### Schema/Migration

**Prisma:**
```prisma
model Product {
  id          String   @id @default(uuid())
  name        String
  price       Float
  description String?
  categoryId  String
  category    Category @relation(fields: [categoryId], references: [id])
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

**Drizzle:**
```typescript
export const products = pgTable('products', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: varchar('name', { length: 255 }).notNull(),
  price: numeric('price', { precision: 10, scale: 2 }).notNull(),
  description: text('description'),
  categoryId: uuid('category_id').references(() => categories.id),
  createdAt: timestamp('created_at').defaultNow(),
  updatedAt: timestamp('updated_at').defaultNow(),
});
```

### Validation Schema

**Zod:**
```typescript
export const createProductSchema = z.object({
  name: z.string().min(1).max(255),
  price: z.number().positive(),
  description: z.string().optional(),
  categoryId: z.string().uuid(),
});

export const updateProductSchema = createProductSchema.partial();
```

## Step 4: Generate Service Layer

```typescript
// src/services/product.service.ts
export class ProductService {
  async list(params: { page: number; limit: number }) { /* pagination query */ }
  async getById(id: string) { /* find by ID or throw */ }
  async create(data: CreateProductInput) { /* validate + insert */ }
  async update(id: string, data: UpdateProductInput) { /* validate + update */ }
  async delete(id: string) { /* soft delete or hard delete per project convention */ }
}
```

Match existing service patterns — constructor injection, static methods, or plain functions depending on what the project uses.

## Step 5: Generate API Routes

```typescript
// src/routes/product.routes.ts
// GET    /api/products        → list (paginated)
// GET    /api/products/:id    → get by ID
// POST   /api/products        → create
// PATCH  /api/products/:id    → update
// DELETE /api/products/:id    → delete
```

Include:
- Input validation middleware (Zod, etc.)
- Auth middleware (if other routes use it)
- Error handling matching existing patterns
- Proper HTTP status codes (200, 201, 204, 400, 404)

## Step 6: Generate Tests

### Unit Tests (Service Layer)

```typescript
describe('ProductService', () => {
  describe('create', () => {
    it('creates a product with valid data', async () => { /* ... */ });
    it('rejects invalid price', async () => { /* ... */ });
  });
  describe('list', () => {
    it('returns paginated results', async () => { /* ... */ });
  });
  describe('getById', () => {
    it('returns product when found', async () => { /* ... */ });
    it('throws when not found', async () => { /* ... */ });
  });
  // update, delete...
});
```

### Integration Tests (API Routes)

```typescript
describe('POST /api/products', () => {
  it('creates a product and returns 201', async () => { /* ... */ });
  it('returns 400 for invalid body', async () => { /* ... */ });
  it('returns 401 without auth', async () => { /* ... */ });
});
// GET, PATCH, DELETE...
```

## Step 7: Generate Frontend (If Applicable)

Only if the project has a frontend. Match existing component patterns.

### List Page
- Table or card grid with pagination
- Search/filter (if other list pages have it)
- Create button → form modal or separate page

### Detail/Edit Page
- Form with all fields
- Validation matching the Zod schema
- Submit handler calling the API

### API Client
```typescript
// src/lib/api/products.ts
export const productsApi = {
  list: (params) => fetch('/api/products?' + new URLSearchParams(params)),
  get: (id) => fetch(`/api/products/${id}`),
  create: (data) => fetch('/api/products', { method: 'POST', body: JSON.stringify(data) }),
  update: (id, data) => fetch(`/api/products/${id}`, { method: 'PATCH', body: JSON.stringify(data) }),
  delete: (id) => fetch(`/api/products/${id}`, { method: 'DELETE' }),
};
```

## Step 8: Register Routes

Add the new routes to the main router/app file:

```typescript
// In src/app.ts or equivalent
import { productRoutes } from './routes/product.routes';
app.use('/api/products', productRoutes);
```

## Step 9: Summary

Print a summary of all generated files:

```
📁 Scaffold Complete: Product

Files created:
  ✅ src/db/schema/product.ts       — Database schema
  ✅ src/validators/product.ts       — Zod validation schemas
  ✅ src/services/product.service.ts — Business logic
  ✅ src/routes/product.routes.ts    — API endpoints
  ✅ src/tests/product.test.ts       — Unit + integration tests
  ✅ src/lib/api/products.ts         — Frontend API client (if applicable)

Next steps:
  1. Run migrations: npx prisma migrate dev --name add-products
  2. Run tests: pnpm test src/tests/product.test.ts
  3. Start dev server: pnpm dev
  4. Test endpoint: curl http://localhost:3000/api/products
```

---

## Rules

- ALWAYS read existing code before generating — match the project's exact patterns
- ALWAYS include validation on create and update operations
- ALWAYS include pagination on list endpoints
- ALWAYS generate both unit and integration tests
- ALWAYS register routes in the main app file
- NEVER generate frontend components if the project is API-only
- NEVER use patterns that don't exist in the project (e.g., don't add class-based services to a functional codebase)
- NEVER generate files in locations that don't match the existing structure
- Include createdAt/updatedAt timestamps unless the project doesn't use them
- Use soft delete if the project has a soft delete pattern, otherwise hard delete
- If the entity has relations, include them in queries (join/include/populate)
