---
name: security-check
description: Deep security audit using the code-reviewer agent (Opus)
---
Run a deep security audit on the current codebase or specified files: $ARGUMENTS

Use the code-reviewer agent (model: opus) to:

1. **Static Analysis**
   - Scan for injection vulnerabilities
   - Check authentication and authorization patterns
   - Verify input validation at all system boundaries
   - Detect hardcoded secrets or credentials

2. **Dependency Audit**
   - Run `npm audit` or equivalent
   - Check for known CVEs in dependencies
   - Flag dependencies with no recent maintenance

3. **Configuration Review**
   - Check environment variable handling
   - Verify CORS configuration
   - Review JWT implementation
   - Check rate limiting

4. **Threat Model** (for new features)
   - Identify attack surfaces
   - Enumerate threat vectors
   - Propose mitigations

Output a security report with severity ratings: CRITICAL / HIGH / MEDIUM / LOW / INFO
