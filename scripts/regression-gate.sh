#!/usr/bin/env bash
set -eo pipefail

# Regression Gate — 3-tier automated quality gate for delivered apps
# Usage: regression-gate.sh [--tier 1|2|3] [--project-dir /path] [--port 3000]
#
# Tier 1 (SMOKE, 30s):  build check, server starts, homepage loads, zero console errors, no broken links
# Tier 2 (FULL, 2min):  + all routes, API health, images, forms, responsive, basic a11y
# Tier 3 (EXHAUSTIVE, 5min): + user flows, form validation, performance, full a11y
#
# Exit codes:
#   0 = PASS (all checks passed or warnings only)
#   1 = FAIL (critical issues found — blocks shipping)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Args ---
TIER=1
PROJECT_DIR="."
PORT=""
SKIP_SERVER=false

while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="$2"; shift 2 ;;
    --project-dir) PROJECT_DIR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --skip-server) SKIP_SERVER=true; shift ;;
    *) shift ;;
  esac
done

cd "$PROJECT_DIR"

# --- State ---
CRITICAL=0
WARNINGS=0
CHECKS_RUN=0
CHECKS_PASSED=0
RESULTS=()
SERVER_PID=""
STARTED_SERVER=false

log_pass() { CHECKS_RUN=$((CHECKS_RUN+1)); CHECKS_PASSED=$((CHECKS_PASSED+1)); RESULTS+=("✅ $1"); }
log_fail() { CHECKS_RUN=$((CHECKS_RUN+1)); CRITICAL=$((CRITICAL+1)); RESULTS+=("❌ $1"); }
log_warn() { CHECKS_RUN=$((CHECKS_RUN+1)); WARNINGS=$((WARNINGS+1)); RESULTS+=("⚠️  $1"); }

cleanup() {
  if [ "$STARTED_SERVER" = true ] && [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# --- Detect project type ---
detect_project() {
  if [ -f "next.config.ts" ] || [ -f "next.config.js" ] || [ -f "next.config.mjs" ]; then
    echo "nextjs"
  elif [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
    echo "vite"
  elif [ -f "package.json" ] && grep -q '"start"' package.json 2>/dev/null; then
    echo "node"
  elif [ -f "manage.py" ]; then
    echo "django"
  elif [ -f "main.py" ] || [ -f "app.py" ]; then
    echo "python"
  else
    echo "static"
  fi
}

PROJECT_TYPE=$(detect_project)

# --- Detect package manager ---
detect_pm() {
  if [ -f "pnpm-lock.yaml" ]; then echo "pnpm"
  elif [ -f "bun.lockb" ]; then echo "bun"
  elif [ -f "yarn.lock" ]; then echo "yarn"
  elif [ -f "package-lock.json" ]; then echo "npm"
  else echo "npm"
  fi
}

PM=$(detect_pm)

echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  REGRESSION GATE — Tier $TIER              ║${NC}"
echo -e "${BOLD}║  Project: ${PROJECT_TYPE} (${PM})              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════
# TIER 1: SMOKE CHECKS (30s)
# ═══════════════════════════════════════════

echo -e "${CYAN}── Tier 1: Smoke Checks ──${NC}"

# Check 1: TypeScript / Build
if [ -f "tsconfig.json" ]; then
  if $PM run typecheck 2>/dev/null || npx tsc --noEmit 2>/dev/null; then
    log_pass "TypeScript: no type errors"
  else
    log_fail "TypeScript: type errors found"
  fi
fi

# Check 2: Lint
if grep -q '"lint"' package.json 2>/dev/null; then
  if $PM run lint 2>&1 | tail -1 | grep -qiE "error|failed"; then
    log_warn "Lint: warnings or errors found"
  else
    log_pass "Lint: clean"
  fi
fi

# Check 3: Build (for production builds)
if [ "$TIER" -ge 2 ] && grep -q '"build"' package.json 2>/dev/null; then
  if $PM run build 2>&1 | tail -5 | grep -qiE "error|failed|ELIFECYCLE"; then
    log_fail "Build: production build failed"
  else
    log_pass "Build: production build succeeds"
  fi
fi

# Check 4: Start dev server
if [ "$SKIP_SERVER" = false ] && [ -f "package.json" ]; then
  # Find available port
  if [ -z "$PORT" ]; then
    PORT=4173  # Use preview port to avoid conflicts
    for p in 4173 4174 4175 4176; do
      if ! lsof -ti:$p >/dev/null 2>&1; then
        PORT=$p
        break
      fi
    done
  fi

  # Check if server is already running on that port
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" 2>/dev/null | grep -q "200"; then
    log_pass "Server: already running on port $PORT"
  else
    # Start dev server
    PORT=$PORT $PM run dev -- -p $PORT &>/dev/null &
    SERVER_PID=$!
    STARTED_SERVER=true

    # Wait for server (max 15s)
    SERVER_READY=false
    for i in $(seq 1 30); do
      if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" 2>/dev/null | grep -qE "200|301|302"; then
        SERVER_READY=true
        break
      fi
      sleep 0.5
    done

    if [ "$SERVER_READY" = true ]; then
      log_pass "Server: starts successfully on port $PORT"
    else
      log_fail "Server: failed to start within 15s"
      # Can't do browser checks without server
      TIER=0
    fi
  fi
fi

BASE_URL="http://localhost:$PORT"

# Check 5: Homepage loads
if [ "$TIER" -ge 1 ] && [ -n "$PORT" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    log_pass "Homepage: loads (HTTP 200)"
  else
    log_fail "Homepage: HTTP $HTTP_CODE (expected 200)"
  fi
fi

# Check 6: No console errors (via curl — check for SSR errors in HTML)
if [ "$TIER" -ge 1 ] && [ -n "$PORT" ]; then
  PAGE_HTML=$(curl -s "$BASE_URL" 2>/dev/null || echo "")
  if echo "$PAGE_HTML" | grep -qiE "error|exception|undefined is not|cannot read prop"; then
    log_warn "Homepage: possible runtime errors in SSR HTML"
  else
    log_pass "Homepage: no SSR errors detected"
  fi
fi

# Check 7: Internal links check
if [ "$TIER" -ge 1 ] && [ -n "$PORT" ]; then
  # Extract links from homepage HTML
  LINKS=$(echo "$PAGE_HTML" | grep -oE 'href="(/[^"]*)"' | sed 's/href="//;s/"//' | sort -u | grep -v '^/$' | grep -v '^#' | head -50)
  BROKEN_LINKS=0
  TOTAL_LINKS=0

  for link in $LINKS; do
    TOTAL_LINKS=$((TOTAL_LINKS+1))
    LINK_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${link}" 2>/dev/null || echo "000")
    if [ "$LINK_CODE" = "404" ] || [ "$LINK_CODE" = "000" ]; then
      BROKEN_LINKS=$((BROKEN_LINKS+1))
      RESULTS+=("  ↳ BROKEN: ${link} (HTTP ${LINK_CODE})")
    fi
  done

  if [ "$BROKEN_LINKS" -eq 0 ]; then
    log_pass "Links: $TOTAL_LINKS checked, 0 broken"
  else
    log_fail "Links: $BROKEN_LINKS broken out of $TOTAL_LINKS"
  fi
fi

# ═══════════════════════════════════════════
# TIER 2: FULL CHECKS (2min)
# ═══════════════════════════════════════════

if [ "$TIER" -ge 2 ] && [ -n "$PORT" ]; then
  echo ""
  echo -e "${CYAN}── Tier 2: Full Checks ──${NC}"

  # Check 8: API routes health
  if [ -d "src/app/api" ] || [ -d "app/api" ] || [ -d "pages/api" ]; then
    API_DIR=""
    [ -d "src/app/api" ] && API_DIR="src/app/api"
    [ -d "app/api" ] && API_DIR="app/api"
    [ -d "pages/api" ] && API_DIR="pages/api"

    API_ROUTES=$(find "$API_DIR" -name "route.ts" -o -name "route.js" -o -name "*.ts" -o -name "*.js" 2>/dev/null | \
      sed "s|$API_DIR||;s|/route\.\(ts\|js\)||;s|\.\(ts\|js\)||" | \
      grep -v "_" | sort -u | head -20)

    API_CHECKED=0
    API_FAILED=0
    for route in $API_ROUTES; do
      API_CHECKED=$((API_CHECKED+1))
      API_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/api${route}" 2>/dev/null || echo "000")
      if [ "$API_CODE" = "404" ] || [ "$API_CODE" = "500" ] || [ "$API_CODE" = "000" ]; then
        API_FAILED=$((API_FAILED+1))
        RESULTS+=("  ↳ API FAIL: /api${route} (HTTP ${API_CODE})")
      fi
    done

    if [ "$API_FAILED" -eq 0 ]; then
      log_pass "API Routes: $API_CHECKED checked, 0 failing"
    else
      log_fail "API Routes: $API_FAILED failing out of $API_CHECKED"
    fi
  fi

  # Check 9: Images / assets
  IMAGES=$(echo "$PAGE_HTML" | grep -oE 'src="(/[^"]*\.(png|jpg|jpeg|svg|webp|gif))"' | sed 's/src="//;s/"//' | sort -u | head -30)
  IMG_MISSING=0
  IMG_TOTAL=0
  for img in $IMAGES; do
    IMG_TOTAL=$((IMG_TOTAL+1))
    IMG_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${img}" 2>/dev/null || echo "000")
    if [ "$IMG_CODE" = "404" ] || [ "$IMG_CODE" = "000" ]; then
      IMG_MISSING=$((IMG_MISSING+1))
      RESULTS+=("  ↳ MISSING IMAGE: ${img}")
    fi
  done
  if [ "$IMG_TOTAL" -gt 0 ]; then
    if [ "$IMG_MISSING" -eq 0 ]; then
      log_pass "Images: $IMG_TOTAL loaded, 0 missing"
    else
      log_fail "Images: $IMG_MISSING missing out of $IMG_TOTAL"
    fi
  fi

  # Check 10: Forms have action handlers
  FORMS=$(echo "$PAGE_HTML" | grep -oiE '<form[^>]*>' | wc -l | tr -d ' ')
  DEAD_FORMS=$(echo "$PAGE_HTML" | grep -oiE '<form[^>]*action=""[^>]*>' | wc -l | tr -d ' ')
  if [ "$FORMS" -gt 0 ]; then
    if [ "$DEAD_FORMS" -eq 0 ]; then
      log_pass "Forms: $FORMS found, all have handlers"
    else
      log_warn "Forms: $DEAD_FORMS of $FORMS have empty action attributes"
    fi
  fi

  # Check 11: Responsive (check for horizontal overflow via meta viewport)
  if echo "$PAGE_HTML" | grep -qiE 'viewport.*width=device-width'; then
    log_pass "Responsive: viewport meta tag present"
  else
    log_warn "Responsive: missing viewport meta tag"
  fi

  # Check 12: Basic accessibility
  IMGS_NO_ALT=$(echo "$PAGE_HTML" | grep -oiE '<img[^>]*>' | grep -cv 'alt=' || echo "0")
  BTNS_EMPTY=$(echo "$PAGE_HTML" | grep -oiE '<button[^>]*></button>' | wc -l | tr -d ' ')
  A11Y_ISSUES=$((IMGS_NO_ALT + BTNS_EMPTY))
  if [ "$A11Y_ISSUES" -eq 0 ]; then
    log_pass "Accessibility: no missing alt text or empty buttons"
  else
    log_warn "Accessibility: $IMGS_NO_ALT images missing alt, $BTNS_EMPTY empty buttons"
  fi
fi

# ═══════════════════════════════════════════
# TIER 3: EXHAUSTIVE CHECKS (5min)
# ═══════════════════════════════════════════

if [ "$TIER" -ge 3 ] && [ -n "$PORT" ]; then
  echo ""
  echo -e "${CYAN}── Tier 3: Exhaustive Checks ──${NC}"

  # Check 13: All pages from sitemap or route structure
  if [ -d "src/app" ]; then
    PAGE_ROUTES=$(find src/app -name "page.tsx" -o -name "page.jsx" -o -name "page.js" 2>/dev/null | \
      sed 's|src/app||;s|/page\.\(tsx\|jsx\|js\)||;s|\[.*\]|test|g' | \
      grep -v "^$" | sort -u | head -30)

    PAGES_CHECKED=0
    PAGES_BROKEN=0
    for route in $PAGE_ROUTES; do
      PAGES_CHECKED=$((PAGES_CHECKED+1))
      P_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${route}" 2>/dev/null || echo "000")
      if [ "$P_CODE" = "500" ] || [ "$P_CODE" = "000" ]; then
        PAGES_BROKEN=$((PAGES_BROKEN+1))
        RESULTS+=("  ↳ BROKEN PAGE: ${route} (HTTP ${P_CODE})")
      fi
    done

    if [ "$PAGES_BROKEN" -eq 0 ]; then
      log_pass "Pages: $PAGES_CHECKED routes checked, 0 broken"
    else
      log_fail "Pages: $PAGES_BROKEN broken out of $PAGES_CHECKED"
    fi
  fi

  # Check 14: Performance (basic — page load time)
  LOAD_TIME=$(curl -s -o /dev/null -w "%{time_total}" "$BASE_URL" 2>/dev/null || echo "99")
  LOAD_MS=$(echo "$LOAD_TIME" | awk '{printf "%d", $1 * 1000}')
  if [ "$LOAD_MS" -lt 3000 ]; then
    log_pass "Performance: homepage loads in ${LOAD_MS}ms (<3s)"
  else
    log_warn "Performance: homepage loads in ${LOAD_MS}ms (>3s, may be slow)"
  fi

  # Check 15: No TODO/FIXME/HACK in shipped code
  if [ -d "src" ]; then
    TODOS=$(grep -rn "TODO\|FIXME\|HACK\|XXX" src/ --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TODOS" -eq 0 ]; then
      log_pass "Code quality: no TODO/FIXME/HACK in source"
    else
      log_warn "Code quality: $TODOS TODO/FIXME/HACK comments in source"
    fi
  fi
fi

# ═══════════════════════════════════════════
# REPORT
# ═══════════════════════════════════════════

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  REGRESSION GATE — Results               ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════╣${NC}"

for r in "${RESULTS[@]}"; do
  echo -e "║  $r"
done

echo -e "${BOLD}╠══════════════════════════════════════════╣${NC}"

if [ "$CRITICAL" -eq 0 ]; then
  echo -e "║  ${GREEN}VERDICT: ✅ PASS${NC} ($CHECKS_PASSED/$CHECKS_RUN passed, $WARNINGS warnings)"
else
  echo -e "║  ${RED}VERDICT: ❌ FAIL${NC} ($CRITICAL critical, $WARNINGS warnings)"
fi

echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"

# Exit non-zero if critical issues found
if [ "$CRITICAL" -gt 0 ]; then
  exit 1
fi

exit 0
