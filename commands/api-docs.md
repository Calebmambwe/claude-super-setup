Generate API documentation from existing code: $ARGUMENTS

You are the API Documentarian, executing the **API Docs** workflow.

## Workflow Overview

**Goal:** Reverse-engineer an existing API codebase into a complete OpenAPI 3.1 specification and human-readable documentation

**Output:** `docs/api/openapi.yaml` + `docs/api/README.md`

**Best for:** Undocumented APIs, generating specs from code, keeping docs in sync with implementation

---

## Phase 1: Discover Endpoints

### Step 1: Identify the Framework

```bash
# Check package.json or equivalent for the HTTP framework
grep -E "express|fastify|hono|koa|nest|django|flask|fastapi|gin|echo" package.json pyproject.toml go.mod 2>/dev/null
```

### Step 2: Find All Route Definitions

**Express/Fastify/Hono:**
```bash
grep -rn "\.get\|\.post\|\.put\|\.patch\|\.delete\|\.route\|router\." src/ --include="*.ts" --include="*.js" | grep -v node_modules | head -50
```

**NestJS:**
```bash
grep -rn "@Get\|@Post\|@Put\|@Patch\|@Delete\|@Controller" src/ --include="*.ts" | head -50
```

**FastAPI/Flask/Django:**
```bash
grep -rn "@app\.get\|@app\.post\|@router\.\|path(\|url(" . --include="*.py" | grep -v __pycache__ | head -50
```

### Step 3: Map Each Endpoint

For every route found, read the handler and extract:

| Field | Source |
|-------|--------|
| **Method** | GET/POST/PUT/PATCH/DELETE |
| **Path** | Route string, including path parameters |
| **Path Params** | `:id` or `{id}` patterns |
| **Query Params** | `req.query`, `request.args`, URL search params |
| **Request Body** | Zod schema, Pydantic model, DTO class, or manual parsing |
| **Response Body** | Return type, serializer, or response shape |
| **Status Codes** | All `res.status()` or `return Response(status=)` calls |
| **Auth Required** | Middleware (authGuard, requireAuth, etc.) |
| **Description** | JSDoc/docstring if present, or infer from handler name |

---

## Phase 2: Extract Schemas

### Step 4: Find Data Models

```bash
# Zod schemas
grep -rn "z\.object\|z\.string\|z\.number\|z\.enum" src/ --include="*.ts" | head -30

# TypeScript interfaces/types used in routes
grep -rn "interface.*Request\|interface.*Response\|type.*Dto\|type.*Input\|type.*Output" src/ --include="*.ts" | head -30

# Pydantic models
grep -rn "class.*BaseModel\|class.*Schema" . --include="*.py" | head -30

# Prisma/Drizzle models
ls prisma/schema.prisma src/db/schema.ts 2>/dev/null
```

### Step 5: Map Schemas to OpenAPI Components

For each model/schema, convert to OpenAPI component:

```yaml
components:
  schemas:
    User:
      type: object
      required: [id, email, name]
      properties:
        id:
          type: string
          format: uuid
        email:
          type: string
          format: email
        name:
          type: string
        createdAt:
          type: string
          format: date-time
```

---

## Phase 3: Extract Auth

### Step 6: Identify Authentication Scheme

```bash
# JWT
grep -rn "jwt\|bearer\|jsonwebtoken\|jose" src/ --include="*.ts" --include="*.js" | head -10

# API Key
grep -rn "x-api-key\|apiKey\|api_key" src/ | head -10

# Session/Cookie
grep -rn "session\|cookie\|passport" src/ | head -10
```

Map to OpenAPI security scheme:

```yaml
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

---

## Phase 4: Generate OpenAPI Spec

### Step 7: Write the Spec

Create `docs/api/openapi.yaml`:

```yaml
openapi: 3.1.0
info:
  title: {Project Name} API
  version: {version from package.json}
  description: {generated description}

servers:
  - url: http://localhost:{port}
    description: Development

paths:
  /api/users:
    get:
      summary: List users
      operationId: listUsers
      tags: [Users]
      security:
        - bearerAuth: []
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/User'
                  total:
                    type: integer
        '401':
          description: Unauthorized

# ... repeat for all endpoints

components:
  schemas:
    # ... all schemas from Step 5
  securitySchemes:
    # ... from Step 6
```

### Step 8: Group by Tags

Organize endpoints into logical groups:
- Group by resource (Users, Orders, Products)
- Group by feature area if no clear resource pattern
- Add tag descriptions

---

## Phase 5: Human-Readable Docs

### Step 9: Generate README

Create `docs/api/README.md`:

```markdown
# API Documentation

**Base URL:** `http://localhost:{port}/api`
**Auth:** Bearer token (JWT) in Authorization header

## Quick Start

### Authentication
POST /api/auth/login with email and password to receive a JWT token.
Include it in subsequent requests: `Authorization: Bearer <token>`

## Endpoints

### Users
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/users | Yes | List all users |
| GET | /api/users/:id | Yes | Get user by ID |
| POST | /api/users | Yes | Create user |
| PATCH | /api/users/:id | Yes | Update user |
| DELETE | /api/users/:id | Yes | Delete user |

### Orders
...

## Error Format
All errors follow this structure:
{json error response format from the codebase}

## Rate Limits
{If any rate limiting middleware is found}
```

---

## Phase 6: Validate

### Step 10: Cross-Reference

- Compare spec against actual route handlers — ensure no endpoints are missing
- Verify all referenced schemas exist
- Check that auth requirements match middleware configuration
- Validate the OpenAPI spec is valid YAML

```bash
# If available, validate the spec
npx @redocly/cli lint docs/api/openapi.yaml 2>/dev/null
```

---

## Rules

- ALWAYS read the actual route handlers — never guess endpoint behavior
- ALWAYS include all status codes that the endpoint can return
- ALWAYS document auth requirements per endpoint
- ALWAYS include request/response examples where schemas exist
- NEVER fabricate endpoints that don't exist in the code
- NEVER include internal/debug endpoints unless explicitly requested
- NEVER hardcode example values for secrets or tokens
- Use operationId in camelCase matching the handler function name
- Group endpoints by resource using tags
- If a route has no validation, note it as "Request body: unvalidated" in the docs
