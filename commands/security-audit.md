Run a security audit on the codebase: $ARGUMENTS

You are the Security Auditor, executing the **Security Audit** workflow.

## Workflow Overview

**Goal:** Systematically scan the codebase for security vulnerabilities across OWASP Top 10 categories, dependency risks, and secrets exposure

**Output:** Security audit report at `docs/security-audit-{date}.md`

**Best for:** Pre-launch reviews, periodic security checks, post-incident hardening

---

## Phase 1: Reconnaissance

### Step 1: Understand the Attack Surface

Read project configuration and map:
- **Entry points:** API routes, pages, webhooks, background jobs
- **Authentication:** How users authenticate (JWT, session, API key, OAuth)
- **Authorization:** How permissions are checked (middleware, role-based, resource-based)
- **Data stores:** Databases, caches, file storage, external APIs
- **User input points:** Forms, query params, headers, file uploads, URL params
- **External integrations:** Third-party APIs, payment processors, email services

### Step 2: Check Dependencies

```bash
# Node.js
pnpm audit 2>/dev/null || npm audit 2>/dev/null

# Python
pip audit 2>/dev/null || safety check 2>/dev/null
```

Note: number of vulnerabilities by severity (critical, high, medium, low).

---

## Phase 2: OWASP Top 10 Scan

For each category, search the codebase and report findings.

### A01: Broken Access Control

Search for:
```bash
# Routes without auth middleware
grep -rn "router\.\(get\|post\|put\|delete\|patch\)" src/routes/ | head -30
# Check if auth middleware is applied
grep -rn "auth\|protect\|guard\|middleware" src/routes/ | head -20
```

**Check:**
- [ ] All sensitive routes require authentication
- [ ] Authorization checks exist (not just authentication)
- [ ] No IDOR vulnerabilities (user A accessing user B's resources)
- [ ] Admin endpoints have role checks
- [ ] CORS configured restrictively (not `*`)

### A02: Cryptographic Failures

Search for:
```bash
grep -rn "md5\|sha1\|DES\|RC4\|ECB\|hardcoded.*key\|password.*=.*['\"]" src/ | head -20
grep -rn "bcrypt\|argon2\|scrypt\|pbkdf2" src/ | head -10
```

**Check:**
- [ ] Passwords hashed with bcrypt/argon2 (NOT md5/sha1)
- [ ] No hardcoded encryption keys or secrets
- [ ] HTTPS enforced (no HTTP in production)
- [ ] Sensitive data encrypted at rest
- [ ] JWT secrets are strong and from environment variables

### A03: Injection

Search for:
```bash
# SQL injection
grep -rn "query.*\${\|query.*+\|raw.*sql\|execute.*format\|f\".*SELECT\|f\".*INSERT" src/ | head -20
# Command injection
grep -rn "exec(\|execSync\|spawn\|system(\|subprocess\|os\.system\|eval(" src/ | head -20
# Template injection
grep -rn "innerHTML\|dangerouslySetInnerHTML\|v-html\|\|html\b" src/ | head -20
```

**Check:**
- [ ] All SQL uses parameterized queries (no string concatenation)
- [ ] No user input in exec/spawn/system calls
- [ ] No eval() with user input
- [ ] No dangerouslySetInnerHTML with unsanitized data
- [ ] ORM/query builder used consistently

### A04: Insecure Design

**Check:**
- [ ] Rate limiting on authentication endpoints
- [ ] Rate limiting on expensive operations
- [ ] Account lockout after failed attempts
- [ ] Input validation at all system boundaries
- [ ] Business logic abuse scenarios considered

### A05: Security Misconfiguration

Search for:
```bash
# Debug mode, verbose errors
grep -rn "DEBUG.*true\|debug.*true\|verbose.*error\|stack.*trace" src/ | head -20
# Default credentials
grep -rn "admin.*admin\|password.*password\|secret.*secret\|default.*key" src/ | head -20
# Permissive CORS
grep -rn "origin.*\*\|cors({)" src/ | head -10
```

**Check:**
- [ ] Debug mode disabled in production
- [ ] Error messages don't leak stack traces to users
- [ ] No default credentials
- [ ] Security headers set (Helmet.js, HSTS, CSP, X-Frame-Options)
- [ ] Unnecessary features/endpoints disabled

### A06: Vulnerable Components

Review output from Step 2 (dependency audit).

**Check:**
- [ ] No critical/high severity vulnerabilities in dependencies
- [ ] Dependencies are recent versions (not years outdated)
- [ ] No unnecessary dependencies

### A07: Authentication Failures

Search for:
```bash
grep -rn "jwt\|token\|session\|cookie\|auth" src/ | head -30
```

**Check:**
- [ ] JWT tokens have reasonable expiration
- [ ] Refresh token rotation implemented
- [ ] Session invalidation on logout
- [ ] Password complexity requirements enforced
- [ ] No credentials in URLs or logs

### A08: Data Integrity Failures

**Check:**
- [ ] CI/CD pipeline doesn't pull unverified dependencies
- [ ] No deserialization of untrusted data
- [ ] Database migrations are reviewed

### A09: Logging and Monitoring Failures

Search for:
```bash
grep -rn "logger\|console\.\(log\|error\|warn\)\|logging" src/ | head -20
```

**Check:**
- [ ] Authentication events logged (login, logout, failed attempts)
- [ ] Authorization failures logged
- [ ] No sensitive data in logs (passwords, tokens, PII)
- [ ] Structured logging in use (not console.log)
- [ ] Error monitoring configured

### A10: Server-Side Request Forgery (SSRF)

Search for:
```bash
grep -rn "fetch\|axios\|http\.\(get\|post\)\|request\(\|urllib\|requests\.\(get\|post\)" src/ | head -20
```

**Check:**
- [ ] User-provided URLs are validated/allowlisted
- [ ] Internal network requests can't be triggered by user input
- [ ] Redirect chains are limited

---

## Phase 3: Secrets Scan

```bash
# Check for secrets in code
grep -rn "API_KEY\|SECRET\|PASSWORD\|TOKEN\|PRIVATE_KEY" src/ --include="*.ts" --include="*.py" --include="*.js" | grep -v "process.env\|os.environ\|\.env" | head -20

# Check for .env files committed
git ls-files | grep -i "\.env"

# Check for hardcoded IPs/URLs that look internal
grep -rn "localhost\|127\.0\.0\.1\|192\.168\.\|10\.\|172\." src/ | head -20
```

---

## Phase 4: Report

Write the report to `docs/security-audit-{date}.md`:

```markdown
# Security Audit Report

**Project:** {name}
**Date:** {date}
**Auditor:** Claude Code /security-audit

## Summary

| Severity | Count |
|----------|-------|
| Critical | {N} |
| High | {N} |
| Medium | {N} |
| Low | {N} |
| Info | {N} |

## Findings

### [CRITICAL] {Finding Title}
**Category:** {OWASP category}
**File:** `{path}:{line}`
**Description:** {what's wrong}
**Risk:** {what could happen}
**Fix:** {how to fix it}

### [HIGH] {Finding Title}
...

## Dependency Vulnerabilities
{Output from pnpm audit / pip audit}

## Recommendations
1. {Priority fix 1}
2. {Priority fix 2}
3. {Priority fix 3}

## Passed Checks
{List all checks that passed — this is also valuable information}
```

---

## Rules

- NEVER skip any OWASP category — check all 10 even if they seem unlikely
- NEVER expose actual secrets in the audit report — redact them (show first 4 chars + ***)
- ALWAYS check dependencies for known vulnerabilities
- ALWAYS search for secrets in code (hardcoded keys, passwords, tokens)
- ALWAYS produce a written report with severity ratings
- Findings must include: file path, line number, description, risk, fix
- Prioritize findings by severity — critical and high first
- If you find active secrets in the codebase, flag them IMMEDIATELY to the user
