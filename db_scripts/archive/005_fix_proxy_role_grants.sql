-- =============================================================================
-- Migration 005: Korrektur proxy_sync-Grants (Review-Befunde aus 004_proxy_role)
-- =============================================================================
-- Kontext:
--   Migration 004 wurde lokal angewendet, bevor drei dba-reviewer-Befunde
--   identifiziert wurden. Da 004 noch nicht auf Prod eingespielt wurde und
--   im Git unverfolgt war, wurde 004 in-place korrigiert (idempotentes Neubild
--   der Ziel-Grants). Diese Migration 005 bringt eine bereits existierende
--   Umgebung (lokal oder Prod, falls 004 je eingespielt worden wäre) auf den
--   korrekten Stand, indem sie überschüssige Grants widerruft.
--
-- Behobene Befunde (dba-reviewer, 2026-05-24):
--
--   [IMPORTANT-1] DELETE-Grant auf Telemetrie-Hypertables entfernt:
--     rapt.telemetry_controllers und rapt.telemetry_hydrometers werden
--     ausschließlich per inkrementellem INSERT (MAX(created_on)-Watermark)
--     befüllt — es gibt keinen Delete-Pfad in db-sync.js. DELETE "defensiv
--     für künftiges Cleanup" verletzt least-privilege und ist ein Footgun
--     (ein Proxy-Bug/Injection könnte Monate an Telemetrie löschen).
--     FIX: REVOKE DELETE auf beiden Telemetrie-Tabellen.
--
--   [IMPORTANT-2] Plaintext-Secret-Exposure in rapt.user_profiles dokumentiert:
--     proxy_sync liest rapt_api_key / rapt_user_id als Klartext-Spalten.
--     Das rapt-Schema hat bisher keine Vault-Migration durchlaufen (anders
--     als aibrewgenius/003_vault.sql). Dieses Muster ist eine bewusste,
--     explizit dokumentierte technische Schuld. Voraussetzung für langfristige
--     Akzeptanz: eine Vault-Migration für rapt.user_profiles analog zu
--     003_vault.sql (rapt_secret_id FK auf vault.secrets, rapt_configured
--     generated column, get_my_rapt_creds() SECURITY DEFINER RPC).
--     FIX: SELECT-Grant bleibt (funktional nötig), Dokumentation ergänzt in
--     004-Header + COMMENT ON ROLE.
--
--   [IMPORTANT-3] Dediziertes Passwort PROXY_SYNC_PASSWORD statt POSTGRES_PASSWORD:
--     Der ursprüngliche Kommentar referenzierte ${POSTGRES_PASSWORD} — das
--     normalisiert ein Anti-Pattern und hebt den least-privilege-Vorteil auf
--     (ein geleaktes DATABASE_URL = Master-DB-Credential).
--     FIX: Alle Kommentare und COMMENT ON ROLE korrigiert auf PROXY_SYNC_PASSWORD.
--     Das tatsächliche Setzen des Passworts + .env.gpg-Re-Encrypt obliegt
--     cicd-coder / Credential-Schritt.
--
--   [OPTIONAL/UMGESETZT] DELETE auf rapt.controllers/hydrometers/profiles entfernt:
--     db-sync.js hat keinen Delete-Pfad für diese drei Stammdaten-Tabellen.
--     Device-Disappearance-Cleanup gehört in die Migration, die den Code einführt.
--     FIX: REVOKE DELETE auf controllers, hydrometers, profiles.
--
-- Idempotenz: REVOKE ist sicher wiederholbar (kein Fehler wenn Grant nicht existiert,
-- da IF EXISTS nicht benötigt wird — Postgres wirft keine Exception bei REVOKE
-- auf nicht vorhandene Privileges, nur eine NOTICE).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. REVOKE überschüssige DELETE-Grants von Telemetrie-Hypertables
--    (IMPORTANT-1: kein Delete-Pfad in db-sync.js, Footgun-Schutz)
-- ---------------------------------------------------------------------------
REVOKE DELETE ON rapt.telemetry_controllers  FROM proxy_sync;
REVOKE DELETE ON rapt.telemetry_hydrometers  FROM proxy_sync;

-- ---------------------------------------------------------------------------
-- 2. REVOKE UPDATE auf Telemetrie-Hypertables
--    (Inkrementeller INSERT-Only-Pfad braucht kein UPDATE auf Hypertables)
-- ---------------------------------------------------------------------------
REVOKE UPDATE ON rapt.telemetry_controllers  FROM proxy_sync;
REVOKE UPDATE ON rapt.telemetry_hydrometers  FROM proxy_sync;

-- ---------------------------------------------------------------------------
-- 3. REVOKE DELETE auf Stammdaten-Tabellen (OPTIONAL/UMGESETZT)
--    controllers, hydrometers, profiles: nur UPSERT-Pfad in db-sync.js.
--    DELETE-Grant kommt in der Migration, die den Cleanup-Code einführt.
-- ---------------------------------------------------------------------------
REVOKE DELETE ON rapt.controllers  FROM proxy_sync;
REVOKE DELETE ON rapt.hydrometers  FROM proxy_sync;
REVOKE DELETE ON rapt.profiles     FROM proxy_sync;

-- ---------------------------------------------------------------------------
-- 4. COMMENT ON ROLE aktualisieren (IMPORTANT-3: PROXY_SYNC_PASSWORD)
-- ---------------------------------------------------------------------------
COMMENT ON ROLE proxy_sync IS
  'Minimal-privilegierte Rolle für den brew-proxy db-sync-Worker. '
  'Darf ausschliesslich rapt.*-Tabellen lesen/schreiben. '
  'Kein BYPASSRLS, kein Zugriff auf aibrewgenius.*/auth.*/vault.*. '
  'Passwort wird via zz-set-role-passwords.sh mit dedizierter PROXY_SYNC_PASSWORD-Variable gesetzt '
  '(NICHT ${POSTGRES_PASSWORD} — geteiltes Master-Passwort hebt least-privilege auf). '
  'Eingeführt in Migration 004 (Phase 1 Multi-VPS); Grants korrigiert in 005.';

-- ---------------------------------------------------------------------------
-- 5. SECURITY NOTE — Plaintext rapt.user_profiles (IMPORTANT-2, dokumentiert)
-- ---------------------------------------------------------------------------
-- proxy_sync behält SELECT auf rapt.user_profiles (rapt_api_key, rapt_user_id
-- als Klartext). Das ist funktional nötig für den Sync-Worker.
-- TECHNISCHE SCHULD: rapt.user_profiles hat keine Vault-Verschlüsselung.
-- Voraussetzung für Behebung: Vault-Migration für rapt-Schema analog zu
-- aibrewgenius/003_vault.sql. Bis dahin: bewusste, dokumentierte Entscheidung.
-- Keine SQL-Änderung hier — nur Dokumentation oben + in Migration 004.

COMMIT;

-- =============================================================================
-- Sanity Checks — Zielzustand nach Migration 005
-- =============================================================================
\echo ''
\echo '== proxy_sync Rolle =='
SELECT rolname, rolsuper, rolbypassrls, rolcanlogin, rolcreaterole, rolcreatedb
FROM pg_roles WHERE rolname = 'proxy_sync';

\echo ''
\echo '== Grants auf rapt.* für proxy_sync (Zielzustand) =='
\echo '   Erwartet: telemetry_* nur SELECT+INSERT; controllers/hydrometers/profiles nur SELECT+INSERT+UPDATE'
\echo '             brew_sessions SELECT+INSERT+UPDATE+DELETE; user_profiles nur SELECT'
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'proxy_sync' AND table_schema = 'rapt'
ORDER BY table_name, privilege_type;

\echo ''
\echo '== DELETE-Grants für proxy_sync (soll leer sein nach 005) =='
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'proxy_sync'
  AND table_schema = 'rapt'
  AND privilege_type = 'DELETE'
  AND table_name IN ('telemetry_controllers','telemetry_hydrometers',
                     'controllers','hydrometers','profiles');

\echo ''
\echo '== Grants auf aibrewgenius.* für proxy_sync (soll leer sein) =='
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'proxy_sync' AND table_schema = 'aibrewgenius';
