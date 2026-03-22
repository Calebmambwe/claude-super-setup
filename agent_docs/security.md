# Security Standards

## Rules
- Never commit secrets or .env files — use .gitignore and GitHub Secrets
- Parameterized queries only — no string interpolation in SQL
- JWT for API auth, validated in middleware before route handlers
- Input validation at all system boundaries using Zod/Pydantic
- Dependencies audited regularly — `npm audit` / `pnpm audit` in CI

## Examples
```typescript
// Good: parameterized query
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);

// Good: input validation at boundary
const schema = z.object({ email: z.string().email(), name: z.string().min(2) });
const validated = schema.parse(req.body);
```

## Anti-Patterns
- String interpolation in SQL: `SELECT * FROM users WHERE id = '${id}'` — SQL injection
- Committing .env files — add `.env*` to .gitignore
- Validating input only on the frontend — always validate server-side
- Storing JWT secrets in code — use environment variables
