#!/usr/bin/env bash
# Restoriert das aibrewgenius Schema (Daten+Struktur) aus einem pg_dump in
# die laufende supabase-db. Vergibt danach die korrekten Berechtigungen auf
# anon/authenticated/service_role, damit PostgREST die Tabellen ausliefert.
#
# Nutzung:
#   ./scripts/restore-from-backup.sh /pfad/zum/aibrewgenius_dump.sql
#   ./scripts/restore-from-backup.sh                  # nimmt das jüngste in ../webPage_infra/backups/

set -euo pipefail

BACKUP_FILE="${1:-}"
if [[ -z "$BACKUP_FILE" ]]; then
  BACKUP_FILE=$(ls -t ../webPage_infra/backups/supabase-legacy-*/01_aibrewgenius.sql 2>/dev/null | head -1 || true)
fi
if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
  echo "Fehler: kein Backup-File gefunden. Pfad als Argument übergeben."
  exit 1
fi
echo "Restore aus: $BACKUP_FILE"

if ! docker ps --format '{{.Names}}' | grep -q '^supabase-db$'; then
  echo "Fehler: supabase-db Container läuft nicht."
  exit 1
fi

echo "1/2  Spiele Dump ein…"
docker exec -i supabase-db psql -U supabase_admin -d postgres < "$BACKUP_FILE" 2>&1 \
  | grep -vE "^(ALTER|COPY|CREATE|SET|GRANT|REVOKE|DROP|invalid command)" \
  | tail -20

echo "2/2  Setze Privileges (single-user Setup: anon=ALL, service_role=ALL)…"
# anon kriegt volle Rechte weil App keinen Auth-Flow hat (legacy single-user Pattern).
# Wenn später Multi-User mit Login dazukommt: anon auf SELECT zurücknehmen, RLS-Policies einführen.
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
echo "OK. PostgREST Schema-Cache neu geladen."

echo
echo "Row-Counts zur Verifikation:"
docker exec supabase-db psql -U supabase_admin -d postgres -c "
SELECT 'recipes' AS t, COUNT(*) FROM aibrewgenius.recipes
UNION ALL SELECT 'batches', COUNT(*) FROM aibrewgenius.batches
UNION ALL SELECT 'fermentables', COUNT(*) FROM aibrewgenius.fermentables;
"
