#!/usr/bin/env bash
# run.sh — Set up env vars and run Playwright tests for brew_assistent-new.
# Usage:
#   ./run.sh                        # all tests
#   ./run.sh tests/smoke.spec.ts    # single file
#   ./run.sh --headed               # headed mode for debugging
#   BASE_URL=https://assistent.alexstuder.cloud ./run.sh  # against remote
#
# Env vars are sourced from brew_assistent-new/.env if the file exists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

# Source .env if present (provides SUPABASE_ANON_KEY, SUPABASE_URL, PROXY_URL)
if [ -f "$ENV_FILE" ]; then
  # Export each non-comment, non-empty line
  set -o allexport
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +o allexport
fi

# --- Default env vars (can be overridden by caller or .env) ---

# App URL — CORRECTED: app is mapped to 8081, NOT 8084
export BASE_URL="${BASE_URL:-http://localhost:8081}"

# Proxy URL
export PROXY_URL="${PROXY_URL:-http://localhost:8083}"

# Supabase
export SUPABASE_URL="${SUPABASE_URL:-http://localhost:54321}"

# SUPABASE_ANON_KEY: sourced from .env above, or set by caller
# If still unset, extract it directly from the .env file as fallback
if [ -z "${SUPABASE_ANON_KEY:-}" ] && [ -f "$ENV_FILE" ]; then
  SUPABASE_ANON_KEY="$(grep '^SUPABASE_ANON_KEY=' "$ENV_FILE" | cut -d= -f2-)"
  export SUPABASE_ANON_KEY
fi

# Test credentials
export TEST_EMAIL="${TEST_EMAIL:-alex@alexstuder.ch}"
export TEST_PASSWORD="${TEST_PASSWORD:-asdf}"

# Optional opt-in flags (unset by default = skip those tests)
# export RUN_OPENAI_TESTS=1   # enables costly OpenAI tests
# export RAPT_TEST_OK=1       # enables RAPT tests (known invalid_grant)
# export BREWFATHER_TEST_OK=1 # enables Brewfather tests

echo ""
echo "=== brew_assistent E2E ==="
echo "  BASE_URL:     $BASE_URL"
echo "  PROXY_URL:    $PROXY_URL"
echo "  SUPABASE_URL: $SUPABASE_URL"
echo "  TEST_EMAIL:   $TEST_EMAIL"
echo ""

cd "$SCRIPT_DIR"
npx playwright test "$@"
