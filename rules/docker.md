---
paths:
  - "**/Dockerfile*"
  - "**/docker-compose*"
  - "**/.dockerignore"
---
# Docker Rules (Loaded for Container Files)

- ALWAYS pin base image versions. Example: `FROM node:22-slim`, never `FROM node:latest`.
- Use multi-stage builds to keep final images small. Build stage installs deps, production stage copies only what's needed.
- NEVER run containers as root. Add `USER node` or `USER appuser` after setup.
- NEVER copy `.env` files into images. Use `.dockerignore` to exclude them.
- Include a `.dockerignore` with: `.env*`, `node_modules/`, `.git/`, `*.md`, `dist/`, `coverage/`.
- Use `COPY package.json pnpm-lock.yaml ./` before `COPY . .` to leverage Docker layer caching.
- Set `HEALTHCHECK` for production containers.
- Prefer `COPY` over `ADD` unless extracting archives.
