#!/usr/bin/env bash
# Generiert alle Supabase-Secrets und schreibt sie nach .env
# (oder gibt einen Patch aus den du in eine zentrale .env paste'st).
#
# Generierte Vars:
#   POSTGRES_PASSWORD       — DB Superuser PW
#   JWT_SECRET              — Signiert ANON_KEY und SERVICE_ROLE_KEY
#   SECRET_KEY_BASE         — Realtime Phoenix Cookie-Secret
#   ANON_KEY                — JWT mit role=anon (was Apps als SUPABASE_ANON_KEY nutzen)
#   SERVICE_ROLE_KEY        — JWT mit role=service_role (admin)
#   DASHBOARD_USERNAME      — Studio HTTP Basic Auth User
#   DASHBOARD_PASSWORD      — Studio HTTP Basic Auth PW
#
# Nutzung:
#   ./scripts/generate-supabase-secrets.sh                          → printet Vars
#   ./scripts/generate-supabase-secrets.sh --write                  → schreibt in ./.env
#   ./scripts/generate-supabase-secrets.sh --write <pfad-zu-env>    → schreibt dort hin

set -euo pipefail

cd "$(dirname "$0")/.."

# Standard-Ziel: lokales .env. Override via $2.
ENV_PATH="${2:-.env}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "Fehler: openssl fehlt" >&2; exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "Fehler: python3 fehlt (für JWT-Signing)" >&2; exit 1
fi

POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '\n=/+' | cut -c1-32)
JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n=/+' | cut -c1-64)
SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n=/+' | cut -c1-64)
DASHBOARD_USERNAME="supabase"
DASHBOARD_PASSWORD=$(openssl rand -base64 24 | tr -d '\n=/+' | cut -c1-24)

# JWT mit HS256 signieren (Python ist überall da, kein extra Tool nötig)
sign_jwt() {
  local role="$1"
  python3 - <<PY
import base64, hmac, hashlib, json, time, sys
secret = "${JWT_SECRET}"
header = {"alg":"HS256","typ":"JWT"}
now = int(time.time())
payload = {"role":"$role","iss":"supabase","iat":now,"exp":now + 10*365*24*3600}
def b64(d):
    return base64.urlsafe_b64encode(json.dumps(d, separators=(',',':')).encode()).rstrip(b'=').decode()
signing_input = f"{b64(header)}.{b64(payload)}"
sig = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
sig_b64 = base64.urlsafe_b64encode(sig).rstrip(b'=').decode()
print(f"{signing_input}.{sig_b64}")
PY
}

ANON_KEY=$(sign_jwt "anon")
SERVICE_ROLE_KEY=$(sign_jwt "service_role")

OUT=$(cat <<EOF
# ─── Supabase Secrets (generiert $(date +%Y-%m-%d_%H:%M:%S)) ───
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET=${JWT_SECRET}
SECRET_KEY_BASE=${SECRET_KEY_BASE}
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
DASHBOARD_USERNAME=${DASHBOARD_USERNAME}
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}

# Apps lesen das hier als SUPABASE_URL / SUPABASE_ANON_KEY:
SUPABASE_PUBLIC_URL=http://localhost:54321
SUPABASE_ANON_KEY=${ANON_KEY}
SUPABASE_SERVICE_KEY=${SERVICE_ROLE_KEY}
EOF
)

if [[ "${1:-}" == "--write" ]]; then
  if [[ -f "$ENV_PATH" ]]; then
    sed -i.bak '/^# ─── Supabase Secrets/,/^SUPABASE_SERVICE_KEY=/d' "$ENV_PATH"
    rm -f "${ENV_PATH}.bak"
  fi
  printf "\n%s\n" "$OUT" >> "$ENV_PATH"
  chmod 600 "$ENV_PATH"
  echo "OK: 9 Supabase-Vars in $ENV_PATH geschrieben/aktualisiert."
else
  echo "$OUT"
  echo
  echo "Tipp: --write [/pfad/zu/.env] um in eine Datei zu schreiben."
fi
