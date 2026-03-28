#!/usr/bin/env bash
set -eo pipefail

# UserPromptSubmit hook — Smart NLP routing
# Detects user intent from natural language and injects context about the right command.
# Does NOT block — just adds helpful context so Claude knows which skill to use.

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")

# Normalize to lowercase for matching
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

CONTEXT=""

# --- Build / Create / Make ---
if echo "$LOWER" | grep -qE '^(build|create|make|scaffold|generate|set up|setup) (me |a |an |the )?'; then
  if echo "$LOWER" | grep -qE 'new (app|project|site|website|service)'; then
    CONTEXT="The user wants to create a new project. Use /new-app to scaffold from a stack template, or /new-project for full automation with CI/CD + GitHub repo."
  elif echo "$LOWER" | grep -qE 'page|component|section|ui|interface|dashboard'; then
    CONTEXT="The user wants to build UI. Use /build-page for page-by-page construction with the design system. Check the design-system skill first."
  elif echo "$LOWER" | grep -qE 'api|endpoint|route|backend|server'; then
    CONTEXT="The user wants to build backend. Use /api-endpoint for a single endpoint, /scaffold for full CRUD, or /api-spec to design the contract first."
  elif echo "$LOWER" | grep -qE 'test|spec|coverage'; then
    CONTEXT="The user wants tests. Use /generate-tests for comprehensive test generation, or /test-plan for a full test strategy."
  fi
fi

# --- Fix / Debug / Broken ---
if echo "$LOWER" | grep -qE '(fix|debug|broken|not working|bug|error|crash|failing|issue)'; then
  CONTEXT="The user has a bug or issue. Use /debug for systematic reproduce→isolate→root-cause→fix→verify pipeline. Read the error first, then the relevant code."
fi

# --- Review / Check / Audit ---
if echo "$LOWER" | grep -qE '(review|check|audit|verify|validate|test it|is it working|does it work)'; then
  if echo "$LOWER" | grep -qE 'security|vulnerab|owasp|injection'; then
    CONTEXT="The user wants a security review. Use /security-audit for OWASP Top 10 scan, or /security-check for deep Opus-level audit."
  elif echo "$LOWER" | grep -qE 'access|a11y|wcag|screen reader|aria'; then
    CONTEXT="The user wants accessibility review. Use /a11y-audit for WCAG 2.2 AA compliance check."
  elif echo "$LOWER" | grep -qE 'performance|slow|speed|load time|optimize'; then
    CONTEXT="The user wants performance review. Use /perf-audit for backend/frontend/database bottleneck analysis."
  elif echo "$LOWER" | grep -qE 'dep|package|outdated|vulnerab|license'; then
    CONTEXT="The user wants dependency audit. Use /deps-audit for security vulnerabilities, outdated packages, and license compliance."
  else
    CONTEXT="The user wants a quality check. Use /check for parallel code-review + security-audit + test verification. Use /regression-gate for runtime app testing (broken links, console errors, API health)."
  fi
fi

# --- Ship / Deploy / PR / Push ---
if echo "$LOWER" | grep -qE '(ship|deploy|push|pr |pull request|merge|release|go live|launch)'; then
  CONTEXT="The user wants to ship. Use /ship for conventional commit + PR. Use /auto-ship for build+check+ship in one pass. ALWAYS run /regression-gate before shipping web apps."
fi

# --- Plan / Think / Design / Architect ---
if echo "$LOWER" | grep -qE '(plan|think|design|architect|how should|what approach|strategy|spec)'; then
  if echo "$LOWER" | grep -qE 'migrat|move from|switch to|convert|upgrade'; then
    CONTEXT="The user wants to migrate technology. Use /migrate-stack for a phased migration plan."
  else
    CONTEXT="The user wants to plan. Use /plan for auto-routed planning (Quick Plan / Feature Spec / Full Pipeline based on scope). Use /spec for a production-quality technical specification."
  fi
fi

# --- Brainstorm / Idea / Feature ---
if echo "$LOWER" | grep -qE '(brainstorm|idea|feature|what if|imagine|concept|think about)'; then
  CONTEXT="The user wants to brainstorm. Use /brainstorm for a 5-minute structured idea→brief session. Use /voice-brainstorm for voice input. Use /bmad:brainstorm for SCAMPER/Six Hats structured ideation."
fi

# --- Research / Learn / How does / What is ---
if echo "$LOWER" | grep -qE '(research|learn|how does|what is|compare|alternative|best practice|trend)'; then
  if echo "$LOWER" | grep -qE 'market|competitor|user|customer'; then
    CONTEXT="The user wants product/market research. Use /bmad:research for market size, competitors, user needs analysis."
  else
    CONTEXT="The user wants technical research. Use Context7 MCP for library docs. Use /teach-me to research unknown tools and create permanent skills."
  fi
fi

# --- Voice / Speak / Talk ---
if echo "$LOWER" | grep -qE '(voice|speak|talk|say|record|microphone|listen)'; then
  CONTEXT="The user wants voice interaction. Use /voice-chat for the unified entry point (routes to Telegram or web app). Use /voice-brainstorm for voice-to-brief on Telegram."
fi

# --- Status / Progress / What's happening ---
if echo "$LOWER" | grep -qE '(status|progress|dashboard|what.s happening|show me|overview|health)'; then
  if echo "$LOWER" | grep -qE 'ghost|overnight|autonomous'; then
    CONTEXT="Use /ghost-status for Ghost Mode progress dashboard."
  elif echo "$LOWER" | grep -qE 'pipeline|task|build'; then
    CONTEXT="Use /pipeline-status for current pipeline progress, dependency graph, and task status."
  elif echo "$LOWER" | grep -qE 'budget|token|cost|usage'; then
    CONTEXT="Use /budget-status for token/tool-call budget in this session."
  elif echo "$LOWER" | grep -qE 'benchmark|score|quality'; then
    CONTEXT="Use /benchmark-status for benchmark score history, trends, and regression alerts."
  elif echo "$LOWER" | grep -qE 'learn|improve|reflect'; then
    CONTEXT="Use /learning-dashboard for learning ledger trends and promotion candidates."
  else
    CONTEXT="Use /dashboard for unified observability: pipeline status, telemetry, alerts, system health. Use /weekly-health for cross-project overview."
  fi
fi

# --- Docs / Document / README ---
if echo "$LOWER" | grep -qE '(document|readme|docs|onboard|explain|walk me through)'; then
  if echo "$LOWER" | grep -qE 'api|endpoint|openapi|swagger'; then
    CONTEXT="Use /api-docs to generate OpenAPI 3.1 spec from existing API code."
  elif echo "$LOWER" | grep -qE 'existing|reverse|understand|how does this work'; then
    CONTEXT="Use /reverse-doc to generate implementation docs from existing code. Use /onboard for an interactive codebase tour."
  elif echo "$LOWER" | grep -qE 'decision|why did|adr|rationale'; then
    CONTEXT="Use /adr to create an Architecture Decision Record."
  fi
fi

# --- Install / Setup / Configure ---
if echo "$LOWER" | grep -qE '(install|setup|configure|add|enable) (mcp|server|tool|plugin)'; then
  CONTEXT="Use /mcp-search to find MCP servers, then /mcp-install to install one. Use /mcp-list to see what's installed. Use /mcp-remove to uninstall."
fi

# --- Refactor / Clean up / Improve code ---
if echo "$LOWER" | grep -qE '(refactor|clean up|improve|simplify|restructure)'; then
  CONTEXT="Use /refactor for safe refactoring with blast radius analysis and tests passing at every step. Use /simplify for quick code review and cleanup."
fi

# --- Morning / Start of day ---
if echo "$LOWER" | grep -qE '(morning|start.*(day|work)|briefing|what.s on|agenda|calendar)'; then
  CONTEXT="Use /morning-brief for daily briefing: calendar, tasks, overnight results, and priorities."
fi

# --- End of day ---
if echo "$LOWER" | grep -qE '(end of day|eod|wrap up|done for (today|the day)|sign off)'; then
  CONTEXT="Use /eod-summary for end-of-day summary: work done, blockers, tomorrow's plan. Also run /reflect to capture session learnings."
fi

# --- Clone / Copy / Replicate ---
if echo "$LOWER" | grep -qE '(clone|copy|replicate|recreate|like|similar to) .*(site|app|page|website|design)'; then
  CONTEXT="Use /clone-app to scrape a URL, identify the stack, and scaffold a replica using templates."
fi

# Output context if we matched something
if [ -n "$CONTEXT" ]; then
  jq -n -c --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
else
  echo '{}'
fi

exit 0
