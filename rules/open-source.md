---
paths:
  - "**/package.json"
  - "**/requirements.txt"
  - "**/pyproject.toml"
  - "**/Cargo.toml"
  - "**/go.mod"
---

# Open-Source Research Standards

- ALWAYS check for existing OSS solutions before writing custom code
- Use Context7 MCP to look up library documentation automatically
- Check license compatibility: MIT, Apache 2.0, BSD, ISC = approved. GPL/AGPL = never without approval
- Evaluate package health: downloads, last commit, contributors, TypeScript types
- Document build-vs-buy decisions in specs or ADRs
- Never use packages with <100 weekly downloads or no recent commits
