#!/usr/bin/env bash
# smoke.sh — curl-based health checks for the brew_assistent stack.
# Exits with non-zero if any check fails.
# Used as a fast CI-gate that does NOT require the Node/Playwright stack.

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8081}"
# PROXY_URL may include a /api suffix — strip it to get the proxy origin
PROXY_URL_RAW="${PROXY_URL:-http://localhost:8083}"
PROXY_ORIGIN=$(python3 -c "from urllib.parse import urlparse; u=urlparse('${PROXY_URL_RAW}'); print(f'{u.scheme}://{u.netloc}')" 2>/dev/null || echo "${PROXY_URL_RAW%%/api*}")
SUPABASE_URL="${SUPABASE_URL:-http://localhost:54321}"

PASS=0
FAIL=0

check() {
  local name="$1"
  local expected_status="$2"
  local url="$3"
  shift 3
  local extra_args=("$@")

  local actual_status
  actual_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${extra_args[@]}" "$url")

  if [ "$actual_status" = "$expected_status" ]; then
    echo "  PASS  [$actual_status]  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  [expected=$expected_status got=$actual_status]  $name"
    FAIL=$((FAIL + 1))
  fi
}

check_body() {
  local name="$1"
  local expected_fragment="$2"
  local url="$3"
  shift 3
  local extra_args=("$@")

  local body
  body=$(curl -s --max-time 10 "${extra_args[@]}" "$url")

  if echo "$body" | grep -q "$expected_fragment"; then
    echo "  PASS  [body contains '$expected_fragment']  $name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  [body missing '$expected_fragment']  $name  (body: ${body:0:200})"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "=== Smoke Checks: brew_assistent stack ==="
echo "  BASE_URL:      $BASE_URL"
echo "  PROXY_ORIGIN:  $PROXY_ORIGIN"
echo "  SUPABASE_URL:  $SUPABASE_URL"
echo ""

# 1. App returns 200
check "App: GET / returns 200" "200" "$BASE_URL"

# 2. App HTML contains flutter marker
check_body "App: HTML contains flt-glass-pane (or flutter-specific script)" "flutter" "$BASE_URL"

# 3. Proxy root returns 200
check "Proxy: GET / returns 200" "200" "$PROXY_ORIGIN"

# 4. Proxy root body contains version/status field
check_body "Proxy: response contains 'Proxy is running'" "Proxy is running" "$PROXY_ORIGIN"

# 5. Supabase auth health
check "Supabase: GET /auth/v1/health returns 200" "200" "$SUPABASE_URL/auth/v1/health"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
