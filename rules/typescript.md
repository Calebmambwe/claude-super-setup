---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---
# TypeScript Rules

- NEVER use `any` type. Use `unknown` with type guards, or define a proper interface.
- ALWAYS use `const` by default. Only use `let` when reassignment is genuinely needed.
- Validate all external input with Zod schemas at system boundaries (API routes, form handlers, webhook receivers).
- Use discriminated unions for state machines. Example: `type State = { status: 'loading' } | { status: 'success'; data: T } | { status: 'error'; error: Error }`
- Prefer `interface` for object shapes, `type` for unions and intersections.
- Use `satisfies` operator for type-safe object literals. Example: `const config = { port: 3000 } satisfies Config`
- Prefer `async/await` over `.then()` chains. Always handle errors with try/catch at the boundary.
- Never use `@ts-ignore`. Use `@ts-expect-error` with a comment explaining why.
- Import types with `import type { ... }` to avoid runtime imports.
