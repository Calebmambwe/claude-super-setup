Run a performance audit on the codebase: $ARGUMENTS

You are the Performance Engineer, executing the **Performance Audit** workflow.

## Workflow Overview

**Goal:** Identify performance bottlenecks, inefficiencies, and optimization opportunities across backend, frontend, and database layers

**Output:** Performance audit report at `docs/perf-audit-{date}.md`

---

## Phase 1: Profile the Application

### Step 1: Understand the Architecture

Read project config and entry points. Map:
- Request handling chain (middleware → route → service → database)
- Database queries and ORM usage
- Caching layer (if any)
- Frontend bundle and rendering strategy
- Background jobs and scheduled tasks

### Step 2: Backend Performance

**N+1 Query Detection:**
```bash
# Find loops that contain database calls
grep -rn "for.*\(await\|\.find\|\.query\|\.get\|\.fetch\)" src/services/ src/routes/ | head -20
# Find queries inside map/forEach
grep -rn "\.\(map\|forEach\).*await" src/ | head -20
```

**Check:**
- [ ] No database calls inside loops (N+1 queries)
- [ ] Bulk operations used where possible (insertMany, whereIn)
- [ ] Pagination on all list endpoints (no unbounded queries)
- [ ] Database connection pooling configured
- [ ] Expensive computations not blocking the event loop

**Missing Indexes:**
```bash
# Find query patterns
grep -rn "WHERE\|where(\|findBy\|orderBy\|groupBy" src/ | head -30
```
Cross-reference with schema/migrations — are queried columns indexed?

**Unnecessary Data Fetching:**
```bash
# Find SELECT * or model.find() without field selection
grep -rn "SELECT \*\|\.find()\|\.findAll()\|\.query()" src/ | head -20
```

**Check:**
- [ ] Queries select only needed columns (no SELECT *)
- [ ] Related data loaded only when needed (no eager loading everything)
- [ ] Response payloads don't include unnecessary fields

### Step 3: Caching Assessment

```bash
# Check for caching usage
grep -rn "cache\|redis\|memcache\|lru\|memoize" src/ | head -20
```

**Check:**
- [ ] Frequently accessed, rarely changing data is cached
- [ ] Cache invalidation strategy exists (TTL, event-based)
- [ ] Expensive computations are memoized
- [ ] Database query results cached where appropriate
- [ ] Static assets have cache headers

### Step 4: Frontend Performance (if applicable)

```bash
# Check bundle size
ls -la dist/ build/ .next/ 2>/dev/null

# Find large imports
grep -rn "import.*from" src/ --include="*.tsx" --include="*.ts" | head -30

# Find non-lazy routes/components
grep -rn "import.*Page\|import.*Component\|import.*View" src/ | head -20
```

**Check:**
- [ ] Code splitting / lazy loading for routes
- [ ] Images optimized (WebP, appropriate sizes, lazy loading)
- [ ] No large libraries imported for small features
- [ ] Tree shaking enabled (no barrel file re-exports of everything)
- [ ] CSS not blocking render
- [ ] Fonts preloaded or using font-display: swap

### Step 5: API Response Performance

**Check:**
- [ ] Response compression enabled (gzip/brotli)
- [ ] Appropriate HTTP caching headers (ETag, Cache-Control)
- [ ] No synchronous operations that could be async
- [ ] Heavy operations offloaded to background jobs
- [ ] Timeouts set on external API calls

### Step 6: Database Performance

Read migration files and schema:

**Check:**
- [ ] Primary keys on all tables
- [ ] Indexes on foreign keys
- [ ] Indexes on frequently queried columns (WHERE, ORDER BY, JOIN)
- [ ] No redundant indexes
- [ ] Appropriate column types (not TEXT where VARCHAR(100) suffices)
- [ ] Soft deletes filtered in queries (WHERE deleted_at IS NULL)
- [ ] Connection pooling configured with appropriate limits

---

## Phase 2: Report

Write to `docs/perf-audit-{date}.md`:

```markdown
# Performance Audit Report

**Project:** {name}
**Date:** {date}

## Summary

| Category | Issues | Severity |
|----------|--------|----------|
| N+1 Queries | {count} | {High/Medium} |
| Missing Indexes | {count} | {High/Medium} |
| Unnecessary Data | {count} | {Medium} |
| No Caching | {count} | {Medium/Low} |
| Frontend Bundle | {status} | {High/Medium/Low} |
| API Response | {count} | {Medium/Low} |

## Findings

### [HIGH] N+1 Query in {file}:{line}
**Description:** {what's happening}
**Impact:** {estimated performance impact}
**Fix:**
```
// Before (N+1):
for (const user of users) {
  const orders = await db.orders.findByUserId(user.id); // N queries
}

// After (1 query):
const orders = await db.orders.findByUserIds(userIds); // 1 query
```

### [MEDIUM] Missing Index on {table}.{column}
...

## Quick Wins (< 30 min each)
1. {Quick fix 1}
2. {Quick fix 2}
3. {Quick fix 3}

## Larger Optimizations (require planning)
1. {Optimization 1 — estimated impact}
2. {Optimization 2 — estimated impact}

## Passed Checks
{List checks that passed}
```

---

## Rules

- ALWAYS check for N+1 queries — this is the #1 backend performance issue
- ALWAYS check for missing indexes on queried columns
- ALWAYS check for unbounded queries (no LIMIT/pagination)
- ALWAYS provide before/after code examples for each finding
- NEVER suggest premature optimization — only flag measurable issues
- NEVER suggest adding caching without identifying what to cache and invalidation strategy
- Prioritize findings by impact: database > API > frontend > cosmetic
- Include quick wins that can be fixed in under 30 minutes
