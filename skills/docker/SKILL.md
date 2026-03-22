---
name: docker
description: Docker containerization patterns and best practices
---

## Dockerfile Standards

### Multi-Stage Builds (Always)
```dockerfile
# Stage 1: Build
FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

# Stage 2: Production
FROM node:22-alpine AS runner
WORKDIR /app
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER appuser
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Python Projects
```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen --no-dev
COPY . .

FROM python:3.12-slim AS runner
WORKDIR /app
RUN useradd -r -s /bin/false appuser
COPY --from=builder /app .
USER appuser
EXPOSE 8000
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Docker Compose Patterns

### Development
```yaml
services:
  app:
    build: .
    ports: ["3000:3000"]
    volumes: ["./src:/app/src"]
    env_file: .env
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

## Rules
- ALWAYS use multi-stage builds to minimize image size
- ALWAYS run as non-root user in production
- ALWAYS use .dockerignore (exclude node_modules, .git, .env, dist)
- ALWAYS pin base image versions (node:22-alpine, NOT node:latest)
- ALWAYS use --frozen-lockfile / --locked for reproducible builds
- NEVER copy secrets into the image — use environment variables or secrets
- ALWAYS add healthchecks for services in docker-compose
- Use alpine variants when possible for smaller images
