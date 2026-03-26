---
name: deps-audit
description: Audit project dependencies for security vulnerabilities, outdated packages, unused deps, and license compliance
---
Audit project dependencies for health, security, and bloat: $ARGUMENTS

You are the Dependency Auditor, executing the **Dependency Audit** workflow.

## Workflow Overview

**Goal:** Audit all project dependencies for security vulnerabilities, outdated packages, unused deps, and license compliance

**Output:** Dependency audit report with actionable recommendations

---

## Step 1: Detect Package Manager

```bash
# Check which package manager and manifest
ls package.json pyproject.toml Cargo.toml go.mod Gemfile 2>/dev/null
```

Read the manifest file to understand all dependencies.

## Step 2: Security Vulnerabilities

**Node.js:**
```bash
pnpm audit --json 2>/dev/null || npm audit --json 2>/dev/null
```

**Python:**
```bash
pip audit 2>/dev/null || uv pip audit 2>/dev/null
```

Categorize findings by severity: critical, high, medium, low.

## Step 3: Outdated Packages

**Node.js:**
```bash
pnpm outdated 2>/dev/null || npm outdated 2>/dev/null
```

**Python:**
```bash
pip list --outdated 2>/dev/null
```

Flag:
- **Major version behind** — likely breaking changes, needs migration plan
- **Minor version behind** — new features available, usually safe to update
- **Patch version behind** — bug fixes, update immediately

## Step 4: Unused Dependencies

Search the codebase for actual usage of each dependency:

```bash
# For each dependency in package.json, check if it's imported anywhere
# Node.js example:
grep -rn "require\|from.*['\"]<package>['\"]" src/ | head -5
```

For each dependency:
- If zero imports found → likely unused → recommend removal
- If only imported in config → still needed
- Check devDependencies separately (build tools, test frameworks)

## Step 5: Bundle Size Impact (Frontend)

For frontend projects, identify heavy dependencies:

```bash
# Check node_modules size per package
du -sh node_modules/* 2>/dev/null | sort -rh | head -20
```

Flag packages > 1MB that might have lighter alternatives.

## Step 6: Duplicate Dependencies

```bash
# Check for duplicate packages (different versions)
pnpm ls --depth=0 2>/dev/null | sort | head -40
```

## Step 7: License Compliance

```bash
# Check licenses (Node.js)
npx license-checker --summary 2>/dev/null
```

Flag any:
- **GPL/AGPL** in a proprietary project (copyleft risk)
- **Unknown** licenses (need investigation)
- **No license** (legally risky)

## Step 8: Report

```markdown
# Dependency Audit Report

**Project:** {name}
**Date:** {date}
**Package Manager:** {pnpm/uv/cargo/etc.}
**Total Dependencies:** {count} ({prod} production, {dev} development)

## Security Vulnerabilities

| Package | Severity | Vulnerability | Fix |
|---------|----------|--------------|-----|
| {pkg} | Critical | {CVE/description} | Upgrade to {version} |
| {pkg} | High | {description} | {fix} |

## Outdated Packages

| Package | Current | Latest | Type | Action |
|---------|---------|--------|------|--------|
| {pkg} | {current} | {latest} | Major | Plan migration |
| {pkg} | {current} | {latest} | Patch | Update now |

## Unused Dependencies
{List packages with no imports found — recommend removal}

## Heavy Dependencies
| Package | Size | Alternative |
|---------|------|-------------|
| {pkg} | {size} | {lighter alternative or "none"} |

## License Issues
{Any copyleft or missing licenses}

## Recommendations
1. **Immediate:** {security fixes}
2. **This sprint:** {patch updates, unused removal}
3. **Plan for:** {major version migrations}
```

---

## Rules

- ALWAYS check security vulnerabilities first — this is the highest priority
- ALWAYS verify "unused" packages by searching for imports before recommending removal
- NEVER recommend removing a package without verifying it's truly unused
- NEVER recommend upgrading a major version without noting it may have breaking changes
- Flag GPL/AGPL licenses in proprietary projects
- Include specific version numbers for upgrade recommendations
