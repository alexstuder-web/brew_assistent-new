#!/usr/bin/env bash
# Initialisiert eine FRISCHE supabase-db mit dem leeren aibrewgenius Schema
# (kein Daten-Restore). Verwendet db_scripts/full/001_init_schema.sql.
# Nutzen wenn du eine leere DB willst — sonst restore-from-backup.sh.

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEMA_FILE="db_scripts/full/001_init_schema.sql"
if [[ ! -f "$SCHEMA_FILE" ]]; then
  echo "Fehler: $SCHEMA_FILE fehlt."
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q '^supabase-db$'; then
  echo "Fehler: supabase-db Container läuft nicht."
  exit 1
fi

echo "1/2  Spiele Schema ein…"
docker exec -i supabase-db psql -U supabase_admin -d postgres < "$SCHEMA_FILE" 2>&1 \
  | grep -vE "^(CREATE|ALTER|SET|GRANT|invalid command)" \
  | tail -10

echo "2/2  Setze Privileges (single-user Setup: anon=ALL)…"
docker exec supabase-db psql -U supabase_admin -d postgres -c "
GRANT USAGE ON SCHEMA aibrewgenius TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA aibrewgenius TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA aibrewgenius TO service_role;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA aibrewgenius TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA aibrewgenius
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA aibrewgenius
  GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA aibrewgenius
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO anon, authenticated, service_role;
NOTIFY pgrst, 'reload schema';
" >/dev/null
echo "OK. Leeres Schema bereit."
