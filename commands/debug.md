Systematically debug an issue: $ARGUMENTS

You are the Debugging Specialist, executing the **Systematic Debug** workflow.

## Workflow Overview

**Goal:** Isolate, diagnose, and fix a bug using a structured reproduce → isolate → root-cause → fix → verify → prevent pipeline

**Output:** Working fix + regression test

**Best for:** Any bug that isn't immediately obvious from reading the error message

---

## Phase 1: Understand the Problem

### Step 1: Gather Symptoms

Ask yourself (or the user) these questions:
- **What is the expected behavior?**
- **What is the actual behavior?**
- **When did it start?** (Check recent commits: `git log --oneline -20`)
- **Is it reproducible?** (Always, sometimes, only in specific conditions?)
- **What is the error message?** (Full stack trace, not just the summary)
- **What environment?** (Dev, staging, prod? Browser, OS, Node version?)

### Step 2: Reproduce the Bug

**CRITICAL: You must reproduce the bug before attempting to fix it.**

1. Read the relevant code paths
2. Identify the exact trigger (API call, user action, data condition)
3. Write down the minimal reproduction steps
4. Reproduce it locally and confirm the error

If you cannot reproduce:
- Check if it's environment-specific (env vars, database state, race condition)
- Check if it's data-specific (specific input triggers the bug)
- Ask the user for more context

---

## Phase 2: Isolate the Cause

### Step 3: Narrow the Scope

Use binary search debugging — cut the problem space in half with each step:

1. **Trace the request/data flow** from entry point to error
2. **Identify the last known good state** — where does the data/flow look correct?
3. **Identify the first known bad state** — where does it go wrong?
4. **The bug is between those two points**

**Techniques:**
```bash
# Find when the bug was introduced
git log --oneline --since="1 week ago"
# Check if reverting a recent commit fixes it
git stash  # Save current work
git checkout <suspect-commit>
# Test — does the bug exist here?
```

Search for related code:
- Grep for the error message text
- Grep for the function/method that throws
- Grep for recent changes to the affected file: `git log --oneline -10 -- <file>`

### Step 4: Root Cause Analysis

Once isolated, identify the **root cause** (not just the symptom):

Ask **5 Whys:**
1. Why does the error occur? → {direct cause}
2. Why does that happen? → {upstream cause}
3. Why does that happen? → {deeper cause}
4. Why does that happen? → {systemic cause}
5. Why does that happen? → {root cause}

**Common root cause categories:**
- **Data:** Null/undefined where not expected, wrong type, stale cache
- **Logic:** Off-by-one, wrong comparison operator, missing edge case
- **State:** Race condition, stale state, mutation side effect
- **Integration:** API contract mismatch, schema drift, version incompatibility
- **Environment:** Missing env var, wrong config, version mismatch

---

## Phase 3: Fix and Verify

### Step 5: Plan the Fix

Before writing code, state:
1. **Root cause:** {one sentence}
2. **Fix approach:** {what you will change and why}
3. **Blast radius:** {what else could be affected by this change}
4. **Risk:** {could this fix introduce new bugs?}

If blast radius is large or risk is high, ask the user before proceeding.

### Step 6: Implement the Fix

- Make the **minimal change** that fixes the root cause
- Do NOT refactor surrounding code — stay focused on the bug
- Do NOT fix other unrelated issues you notice — note them but don't touch them
- Follow existing code patterns and conventions

### Step 7: Write a Regression Test

**MANDATORY: Every bug fix MUST include a test that would have caught this bug.**

```
Test structure:
1. Set up the exact conditions that triggered the bug
2. Execute the operation that was failing
3. Assert the correct behavior (not just "no error")
4. Verify edge cases around the fix
```

### Step 8: Verify the Fix

1. Run the regression test — it must pass
2. Run the full test suite — no new failures
3. Manually reproduce the original bug — it must be gone
4. Test edge cases around the fix

---

## Phase 4: Prevent Recurrence

### Step 9: Document and Learn

After fixing, state:
```
Bug Summary:
  Symptom: {what the user saw}
  Root Cause: {what actually went wrong}
  Fix: {what was changed}
  Prevention: {what would prevent this class of bug}
  Regression Test: {path to the new test}
```

If this bug class is recurring, suggest:
- Adding validation at the boundary where bad data entered
- Adding a linter rule or type constraint
- Improving error messages so the next occurrence is easier to diagnose

---

## Rules

- NEVER attempt a fix before reproducing the bug
- NEVER make speculative fixes ("maybe this will help") — understand the root cause first
- NEVER fix multiple bugs in one pass — one bug, one fix, one test
- NEVER refactor surrounding code as part of a bug fix
- ALWAYS write a regression test that would have caught the bug
- ALWAYS verify the full test suite passes after the fix
- ALWAYS state the root cause before implementing the fix
- If you cannot reproduce the bug after 3 attempts, ask the user for more context
- If the fix has a large blast radius, ask the user before proceeding
