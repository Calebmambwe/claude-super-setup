---
name: team-build
description: Orchestrate multiple specialist agents working on a feature in parallel
---
Orchestrate a team of agents to build: $ARGUMENTS

## Team Composition
Based on the feature requirements, assemble the appropriate team:

### Default Team (3 agents)
1. **Implementation Agent** -- writes the feature code
   - Worktree: .claude/worktrees/impl-{feature}
   - Branch: feature/{feature}
   - Agent: backend-architect or frontend-developer (based on task type)

2. **Test Agent** -- writes tests for the feature
   - Worktree: .claude/worktrees/test-{feature}
   - Branch: test/{feature}
   - Agent: test-writer-fixer

3. **Documentation Agent** -- writes docs and updates changelog
   - Worktree: .claude/worktrees/docs-{feature}
   - Branch: docs/{feature}
   - Agent: general-purpose

### Extended Team (add as needed)
4. **Security Agent** -- reviews for vulnerabilities (model: opus)
   - Worktree: .claude/worktrees/security-{feature}
   - Agent: code-reviewer (with security focus)

5. **Performance Agent** -- runs benchmarks and profiling
   - Worktree: .claude/worktrees/perf-{feature}
   - Agent: general-purpose (with performance focus)

## Orchestration
1. Read the spec and task list for the feature
2. Distribute tasks to agents based on specialty
3. Launch agents in parallel worktrees
4. Monitor progress and handle failures
5. Merge all branches sequentially (impl first, then tests, then docs)
6. Run full verification lattice
7. Create PR with combined changes

## Rules
- Implementation agent works first; test and docs agents can start in parallel
  but must reference impl agent's branch for API contracts
- Security review runs AFTER implementation merges
- Never merge docs or tests without passing implementation
