-- =============================================================================
-- Migration 004: Dedizierte Proxy-Rolle proxy_sync für Cross-VPS-Zugriff
-- =============================================================================
-- Hintergrund:
--   Im Single-VPS-Setup verbindet sich der Proxy als `postgres` über den
--   Docker-Service-Namen supabase-db:5432 ohne TLS (alles im selben brewing_net).
--   Im Cross-VPS-Setup kommt die DB-Verbindung über einen cloudflared access tcp
--   Tunnel-Loopback an. Wir nutzen diese Gelegenheit, um eine dedizierte,
--   minimal-privilegierte Rolle einzuführen.
--
-- Warum NICHT weiter `postgres`:
--   - `postgres` hat BYPASSRLS — falls der Proxy-Pool jemals aibrewgenius.*
--     direkt abfragt, sieht er alle Zeilen aller User. Das ist ein latentes
--     Privileg-Risiko, auch wenn der aktuelle Code das nicht tut.
--   - Least-privilege erfordert eine Rolle, die ausschließlich das kann, was
--     der db-sync-Worker braucht.
--
-- Was proxy_sync braucht (aus db-sync.js, verifiziert):
--   - SELECT auf rapt.user_profiles (RAPT-Credentials für den Sync laden)
--   - SELECT/INSERT/UPDATE auf rapt.controllers, rapt.hydrometers, rapt.profiles
--     (UPSERT-Pfad; kein Delete-Pfad in db-sync.js; DELETE kommt in der Migration
--      die den Cleanup-Code einführt)
--   - SELECT/INSERT auf rapt.telemetry_controllers, rapt.telemetry_hydrometers
--     (rein inkrementeller INSERT über MAX(created_on)-Watermark; kein DELETE-Pfad)
--   - SELECT/INSERT/UPDATE/DELETE auf rapt.brew_sessions
--     (deriveBrewSessions schreibt + überschreibt Sessions; Cleanup via DELETE möglich)
--   - Kein Zugriff auf aibrewgenius.* (alle aibrewgenius-Creds laufen über
--     Kong-RPC mit User-JWT, nie über den direkten Pool)
--
-- Was proxy_sync NICHT bekommt:
--   - BYPASSRLS (rapt.* hat RLS deaktiviert — nicht nötig;
--     aibrewgenius.* hat RLS aktiv — BYPASSRLS wäre Privileg-Eskalation)
--   - SUPERUSER / CREATEROLE / CREATEDB
--   - Zugriff auf auth.*, vault.*, storage.*, _realtime.*
--
-- TLS / sslmode-Entscheidung (V-3 verifiziert):
--   `SHOW ssl` im laufenden supabase/postgres:15.8.1.060 ergibt `off`.
--   pg_hba.conf enthält `host` (nicht `hostssl`) Einträge — der Server
--   akzeptiert Verbindungen ohne TLS. `sslmode=require` würde fehlschlagen.
--   => sslmode=disable ist korrekt für den direkten TCP-Transport.
--   Der Cloudflare Tunnel verschlüsselt den Transport auf Netzwerkebene
--   (TLS 1.3 zwischen cloudflared-Diensten), sodass kein Klartext über
--   öffentliche Netze geht. `sslmode=disable` ist damit sicher und korrekt.
--
-- Passwort: NICHT in dieser Migration hartkodiert.
--   cicd-coder muss in zz-set-role-passwords.sh einen Eintrag ergänzen:
--     ALTER ROLE proxy_sync WITH PASSWORD '${PROXY_SYNC_PASSWORD}';
--   WICHTIG: PROXY_SYNC_PASSWORD ist eine DEDIZIERTE Variable — NICHT ${POSTGRES_PASSWORD}.
--   Ein geteiltes Master-Passwort würde den least-privilege-Vorteil aufheben:
--   ein geleaktes DATABASE_URL wäre dann gleichbedeutend mit dem Master-DB-Credential.
--   Und DATABASE_URL in .env setzen (siehe Connection-Vertrag unten).
--
-- Connection-Vertrag (Schnittstelle für cicd-coder):
--   DATABASE_URL=postgres://proxy_sync:${PROXY_SYNC_PASSWORD}@<host>:<port>/postgres?sslmode=disable
--   Lokal (Single-VPS):  host=supabase-db, port=5432
--   Cross-VPS (Tunnel):  host=localhost,   port=<tunnel-loopback-port>
--   Override-Key (compose env): DATABASE_URL
--
-- SECURITY NOTE — Plaintext Secrets in rapt.user_profiles:
--   proxy_sync bekommt SELECT auf rapt.user_profiles, das rapt_api_key und
--   rapt_user_id als KLARTEXT-Spalten hält. Das rapt-Schema hat bisher keine
--   Vault-Migration durchlaufen (anders als aibrewgenius, das in 003_vault.sql
--   auf pgsodium-verschlüsselte vault.secrets migriert wurde).
--   Das bedeutet: die RAPT-Credentials fließen im Klartext über den DB-Pool
--   — auch wenn der Cloudflare Tunnel den Transport verschlüsselt, sind sie
--   im DB-Dump und für jeden DB-Admin lesbar.
--   VORAUSSETZUNG für langfristige Akzeptanz dieses Musters:
--   Eine Vault-Migration für rapt.user_profiles analog zu 003_vault.sql
--   (aibrewgenius-Muster: rapt_secret_id FK auf vault.secrets, rapt_configured
--   generated column, get_my_rapt_creds() SECURITY DEFINER RPC).
--   Bis diese Migration existiert, gilt rapt.user_profiles als technische Schuld.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Rolle anlegen (idempotent)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'proxy_sync') THEN
    CREATE ROLE proxy_sync
      WITH LOGIN
           NOSUPERUSER
           NOCREATEROLE
           NOCREATEDB
           NOREPLICATION
           NOBYPASSRLS
           INHERIT;
    RAISE NOTICE 'Rolle proxy_sync erstellt.';
  ELSE
    RAISE NOTICE 'Rolle proxy_sync existiert bereits — überspringe CREATE.';
  END IF;
END
$$;

-- Sicherheitsattribute explizit setzen, auch wenn Rolle schon existiert.
-- Kein PASSWORD hier — wird via zz-set-role-passwords.sh mit PROXY_SYNC_PASSWORD gesetzt (cicd-coder).
ALTER ROLE proxy_sync
  NOSUPERUSER
  NOCREATEROLE
  NOCREATEDB
  NOREPLICATION
  NOBYPASSRLS
  INHERIT;

-- ---------------------------------------------------------------------------
-- 2. Datenbankzugriff
-- ---------------------------------------------------------------------------
GRANT CONNECT ON DATABASE postgres TO proxy_sync;

-- ---------------------------------------------------------------------------
-- 3. Schema-Zugriff (nur rapt, kein aibrewgenius)
-- ---------------------------------------------------------------------------
GRANT USAGE ON SCHEMA rapt TO proxy_sync;

-- ---------------------------------------------------------------------------
-- 4. Tabellen-Grants auf rapt.* (minimal: genau was db-sync.js braucht)
-- ---------------------------------------------------------------------------

-- rapt.user_profiles: nur SELECT (RAPT-Creds für Sync laden).
-- SECURITY NOTE: rapt_api_key / rapt_user_id sind hier Klartext-Spalten.
-- Siehe Vault-Schuld im Migrations-Header oben.
GRANT SELECT ON rapt.user_profiles TO proxy_sync;

-- rapt.controllers, hydrometers, profiles: UPSERT (SELECT/INSERT/UPDATE) + fallback-SELECT.
-- Kein DELETE: db-sync.js hat keinen Delete-Pfad für diese Tabellen.
-- DELETE-Grant wird in der Migration ergänzt, die den Cleanup-Code einführt.
GRANT SELECT, INSERT, UPDATE ON rapt.controllers          TO proxy_sync;
GRANT SELECT, INSERT, UPDATE ON rapt.hydrometers          TO proxy_sync;
GRANT SELECT, INSERT, UPDATE ON rapt.profiles             TO proxy_sync;

-- rapt.telemetry_controllers, telemetry_hydrometers: rein inkrementaler INSERT + MAX(created_on)-SELECT.
-- Hypertables — kein DELETE-Pfad in db-sync.js. DELETE-Grant nur wenn Cleanup-Code existiert.
-- Ein Proxy-Bug oder Injection könnte andernfalls Monate an Telemetrie löschen.
GRANT SELECT, INSERT ON rapt.telemetry_controllers  TO proxy_sync;
GRANT SELECT, INSERT ON rapt.telemetry_hydrometers  TO proxy_sync;

-- rapt.brew_sessions: deriveBrewSessions INSERT/UPDATE + tryServeFallbackFromDb SELECT.
-- DELETE behalten: Sessions können bei Gap-Re-Detection überschrieben/gelöscht werden.
GRANT SELECT, INSERT, UPDATE, DELETE ON rapt.brew_sessions        TO proxy_sync;

-- Sequenzen: brew_sessions.id ist uuid (gen_random_uuid()), kein serial —
-- USAGE/SELECT wird defensiv gesetzt für zukünftige Tabellen mit serial PKs.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA rapt TO proxy_sync;

-- Explizit KEIN Zugriff auf aibrewgenius.* — keine GRANT-Anweisungen dort.
-- Explizit KEIN Zugriff auf auth.*, vault.*, storage.* — nicht nötig und sicherheitskritisch.

-- ---------------------------------------------------------------------------
-- 5. Kommentar für Dokumentation
-- ---------------------------------------------------------------------------
COMMENT ON ROLE proxy_sync IS
  'Minimal-privilegierte Rolle für den brew-proxy db-sync-Worker. '
  'Darf ausschliesslich rapt.*-Tabellen lesen/schreiben. '
  'Kein BYPASSRLS, kein Zugriff auf aibrewgenius.*/auth.*/vault.*. '
  'Passwort wird via zz-set-role-passwords.sh mit dedizierter PROXY_SYNC_PASSWORD-Variable gesetzt '
  '(NICHT ${POSTGRES_PASSWORD} — geteiltes Master-Passwort hebt least-privilege auf). '
  'Eingeführt in Migration 004 (Phase 1 Multi-VPS); Grants korrigiert in 005.';

COMMIT;

-- =============================================================================
-- Sanity Checks (read-only, nicht-destruktiv)
-- =============================================================================
\echo ''
\echo '== Rolle proxy_sync =='
SELECT rolname, rolsuper, rolbypassrls, rolcanlogin, rolcreaterole, rolcreatedb
FROM pg_roles WHERE rolname = 'proxy_sync';

\echo ''
\echo '== Grants auf rapt.* für proxy_sync =='
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'proxy_sync' AND table_schema = 'rapt'
ORDER BY table_name, privilege_type;

\echo ''
\echo '== Grants auf aibrewgenius.* für proxy_sync (soll leer sein) =='
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'proxy_sync' AND table_schema = 'aibrewgenius';
