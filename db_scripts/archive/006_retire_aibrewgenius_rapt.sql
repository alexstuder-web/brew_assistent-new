-- =============================================================================
-- Migration 006: aibrewgenius RAPT-Creds retiren — Delegation an rapt-Schema
-- =============================================================================
-- Kontext (Epic: RAPT_MULTITENANT_EPIC.md, Phase 1, Schritt 2):
--   Die kanonische RAPT-Cred-Quelle wechselt in die rapt-Domäne (rapt.user_profiles
--   + vault.secrets), gemanagt via rapt.set_my_rapt_creds / rapt.get_my_rapt_creds
--   (angelegt in RAPT_Brewing_Dashboard-new/db_scripts/004_rapt_user_vault.sql).
--   Diese Migration RETIRED die aibrewgenius-RAPT-Teile sanft:
--     - Bestehende aibrewgenius-RAPT-Vault-Einträge → rapt-Store transferiert
--     - aibrewgenius.set_my_rapt_creds → Cross-Schema-Delegation an rapt.set_my_rapt_creds
--     - aibrewgenius.get_my_rapt_creds → Cross-Schema-Delegation an rapt.get_my_rapt_creds
--     - rapt_secret_id / rapt_configured: DEPRECATED (kommentiert, wird NULL/false bleiben)
--
-- Was NICHT passiert (explizit):
--   - KEIN Hard-Drop von Spalten/Funktionen (eigene Aufräum-Migration später)
--   - KEIN Anfassen von Brewfather-Creds (brewfather_secret_id, brewfather_configured,
--     get/set_my_brewfather_creds — vollständig unverändert)
--   - KEINE RLS-Änderungen (user_profiles-RLS aus 002_auth.sql bleibt)
--
-- Idempotenz: 2× anwendbar. Jeder Schritt prüft seinen Vorzustand.
-- DDL läuft als supabase_admin (Owner aller aibrewgenius-Objekte).
-- Voraussetzung: rapt/004_rapt_user_vault.sql bereits angewendet
--   (rapt.set_my_rapt_creds, rapt.get_my_rapt_creds müssen existieren).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- STEP 1: Bestehende aibrewgenius-RAPT-Keys in den rapt-Store transferieren
-- ---------------------------------------------------------------------------
-- Für jeden User, dessen rapt_secret_id in aibrewgenius gesetzt ist
-- (Klartext-Key bereits migriert via 003_vault.sql), den entschlüsselten Wert
-- in rapt.user_profiles + vault.secrets überführen — sofern rapt noch keinen
-- Eintrag hat. Danach: aibrewgenius.rapt_secret_id auf NULL und Vault-Row löschen.
--
-- Idempotenz: WHERE-Bedingungen verhindern Doppel-Ausführung.
-- Transaktion schützt Konsistenz: Transfer + Cleanup als atomare Einheit.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r                    record;
  v_decrypted_key      text;
  v_new_secret_id      uuid;
  v_existing_secret_id uuid;
  row_count            integer := 0;  -- Fix 1: expliziter Zähler statt FOUND-Heuristik
BEGIN
  FOR r IN
    SELECT
      ab.id               AS uid,
      ab.rapt_user_id     AS rapt_user_id,
      ab.rapt_secret_id   AS ab_secret_id
    FROM aibrewgenius.user_profiles ab
    WHERE ab.rapt_secret_id IS NOT NULL   -- Hat aibrewgenius-RAPT-Vault-Eintrag
  LOOP
    -- Entschlüsselt lesen (läuft als supabase_admin = Vault-Owner)
    SELECT ds.decrypted_secret::text INTO v_decrypted_key
    FROM vault.decrypted_secrets ds
    WHERE ds.id = r.ab_secret_id;

    IF v_decrypted_key IS NULL THEN
      RAISE WARNING 'STEP 1: Vault-Decrypt für user % fehlgeschlagen (secret_id %). Übersprungen.',
        r.uid, r.ab_secret_id;
      CONTINUE;
    END IF;

    -- Sicherstellen dass rapt.user_profiles-Row existiert.
    -- läuft als supabase_admin (Schema-Owner); RLS-Bypass hier erwartet.
    INSERT INTO rapt.user_profiles (id, name, updated_at)
    VALUES (r.uid, COALESCE(r.rapt_user_id, 'Brewer'), now())
    ON CONFLICT (id) DO NOTHING;

    -- Nur in rapt transferieren wenn dort noch kein RAPT-Key vorhanden ist
    -- (rapt.user_profiles.rapt_secret_id IS NULL → kein vorhandener rapt-Vault-Eintrag)
    IF EXISTS (
      SELECT 1 FROM rapt.user_profiles
      WHERE id = r.uid AND rapt_secret_id IS NULL
    ) THEN
      -- Fix 2: Pre-Prüfung auf bereits existierende Vault-Row gleichen Namens
      -- (kann entstehen wenn 004_rapt_user_vault.sql partiell lief und schon
      --  'rapt_dash_<uuid>' anlegt hat). Existiert der Eintrag → ID wiederverwenden
      -- statt Dublette zu erzeugen; existiert er nicht → neu anlegen.
      SELECT s.id INTO v_existing_secret_id
      FROM vault.secrets s
      WHERE s.name = 'rapt_dash_' || r.uid::text;

      IF v_existing_secret_id IS NOT NULL THEN
        -- Vault-Row bereits vorhanden (partieller Vorlauf) → ID wiederverwenden,
        -- Secret-Inhalt aktualisieren, keine zweite Row anlegen.
        PERFORM vault.update_secret(
          secret_id  => v_existing_secret_id,
          new_secret => v_decrypted_key
        );
        v_new_secret_id := v_existing_secret_id;
        RAISE NOTICE 'STEP 1: Vault-Row rapt_dash_% existiert bereits (partieller Vorlauf) — ID % wiederverwendet.',
          r.uid, v_existing_secret_id;
      ELSE
        -- Neues Secret im rapt-Namespace anlegen
        v_new_secret_id := vault.create_secret(
          new_secret      => v_decrypted_key,
          new_name        => 'rapt_dash_' || r.uid::text,
          new_description => 'RAPT API key for user ' || r.uid::text
        );
      END IF;

      UPDATE rapt.user_profiles
      SET rapt_secret_id = v_new_secret_id,
          rapt_user_id   = r.rapt_user_id,
          rapt_api_key   = NULL,
          updated_at     = now()
      WHERE id = r.uid;
      RAISE NOTICE 'STEP 1: RAPT-Key für user % in rapt-Store übertragen. rapt secret_id=%',
        r.uid, v_new_secret_id;
    ELSE
      RAISE NOTICE 'STEP 1: rapt-Store für user % hat bereits einen Key — Transfer übersprungen.', r.uid;
    END IF;

    -- Sicherstellen dass rapt-Transfer erfolgt ist, bevor aibrewgenius-Eintrag gelöscht wird
    IF NOT EXISTS (
      SELECT 1 FROM rapt.user_profiles
      WHERE id = r.uid AND rapt_secret_id IS NOT NULL
    ) THEN
      RAISE EXCEPTION 'STEP 1: Konsistenzfehler — rapt-Store für user % hat nach Transfer keinen Key. Rollback.',
        r.uid;
    END IF;

    -- aibrewgenius-Referenz nullen + alten Vault-Eintrag löschen (Single-Source-Prinzip)
    UPDATE aibrewgenius.user_profiles
    SET rapt_secret_id = NULL
    WHERE id = r.uid;

    DELETE FROM vault.secrets WHERE id = r.ab_secret_id;

    RAISE NOTICE 'STEP 1: aibrewgenius rapt_secret_id für user % genullt, alter Vault-Eintrag gelöscht.', r.uid;

    -- Fix 1: NUR bei echtem Datentransfer inkrementieren (CONTINUE-Pfade oben
    -- zählen nicht — sie repräsentieren keinen erfolgreichen Transfer).
    row_count := row_count + 1;
  END LOOP;

  -- Fix 1: Zähler-basierter No-op-Check, nicht FOUND (FOUND wäre true sobald der
  -- Cursor irgendeine Zeile lieferte, auch wenn alle Transfers via CONTINUE übersprungen wurden).
  IF row_count = 0 THEN
    RAISE NOTICE 'STEP 1: Keine aibrewgenius-RAPT-Vault-Einträge transferiert — No-op (Daten bereits im rapt-Store oder kein Key vorhanden).';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- STEP 2: aibrewgenius.set_my_rapt_creds(p_api_key text)
--         → Cross-Schema-Delegation an rapt.set_my_rapt_creds(p_rapt_user_id, p_api_key)
-- ---------------------------------------------------------------------------
-- Die aibrewgenius-Signatur hat nur einen Parameter (p_api_key); die rapt-RPC
-- braucht zusätzlich p_rapt_user_id. Wir lesen ihn aus aibrewgenius.user_profiles,
-- wo er nach 002_auth.sql gepflegt ist. Falls dort NULL, Fallback auf NULL
-- (rapt.set_my_rapt_creds akzeptiert NULL und räumt rapt_user_id dann aus).
--
-- SECURITY DEFINER + SET search_path = '' beibehalten.
-- auth.uid()-Filter via Delegation: rapt.set_my_rapt_creds prüft intern auth.uid()
-- zusätzlich tun wir hier einen eigenen NULL-Prüfcheck (defense in depth).
--
-- DEPRECATED: Diese Funktion ist ein Sicherheitsnetz für noch nicht umgestellte
-- Clients. Kanonischer Aufrufpfad: rapt.set_my_rapt_creds(rapt_user_id, api_key)
-- direkt aus flutter-coder (brew_assistent RAPT_MULTITENANT_P1_FLUTTER.md).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aibrewgenius.set_my_rapt_creds(p_api_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
-- DEPRECATED (Phase 1 aibrewgenius-RAPT-Retire): Delegation an rapt.set_my_rapt_creds.
-- Schreibt nicht mehr in aibrewgenius.user_profiles.rapt_secret_id,
-- sondern in den rapt-Store. Hard-Drop in späterer Aufräum-Migration.
DECLARE
  v_uid           uuid := auth.uid();
  v_rapt_user_id  text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- rapt_user_id aus aibrewgenius.user_profiles lesen, um die rapt-RPC-Signatur zu befüllen.
  SELECT up.rapt_user_id INTO v_rapt_user_id
  FROM aibrewgenius.user_profiles up
  WHERE up.id = v_uid;

  -- Fix 3: BC4-Fallback — kein aibrewgenius-Eintrag (oder rapt_user_id IS NULL dort).
  -- Ohne Fallback würde v_rapt_user_id NULL sein → rapt.set_my_rapt_creds(NULL, key)
  -- überschreibt einen bereits gesetzten rapt_user_id in der rapt-Row mit NULL.
  -- Stattdessen: wenn kein aibrewgenius-Username bekannt, bestehenden rapt-Username
  -- aus rapt.user_profiles lesen und damit die Delegation befüllen.
  IF v_rapt_user_id IS NULL THEN
    SELECT up.rapt_user_id INTO v_rapt_user_id
    FROM rapt.user_profiles up
    WHERE up.id = v_uid;
  END IF;

  -- Delegation: auth.uid() ist als Sitzungskontext erhalten (PostgREST setzt
  -- request.jwt.claims sessionweit; rapt.set_my_rapt_creds ruft auth.uid() intern auf).
  PERFORM rapt.set_my_rapt_creds(v_rapt_user_id, p_api_key);
END $$;

-- Grants unverändernd belassen (REVOKE + GRANT idempotent)
REVOKE EXECUTE ON FUNCTION aibrewgenius.set_my_rapt_creds(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION aibrewgenius.set_my_rapt_creds(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- STEP 3: aibrewgenius.get_my_rapt_creds()
--         → Cross-Schema-Delegation an rapt.get_my_rapt_creds()
-- ---------------------------------------------------------------------------
-- Return-Shape (username text, api_key text) bleibt identisch — der Proxy-Aufruf
-- (server.js Content-Profile: aibrewgenius) bekommt dieselbe Struktur.
-- Proxy wird in Phase 1 Schritt 3 auf Content-Profile: rapt umgestellt;
-- bis dahin ist diese Delegation das Sicherheitsnetz.
--
-- SECURITY DEFINER + SET search_path = '' beibehalten.
-- auth.uid()-Filter: rapt.get_my_rapt_creds() prüft intern auth.uid().
--
-- DEPRECATED: Sicherheitsnetz für Proxy-Schritt 3 (RAPT_MULTITENANT_P1).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aibrewgenius.get_my_rapt_creds()
RETURNS TABLE (username text, api_key text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
-- DEPRECATED (Phase 1 aibrewgenius-RAPT-Retire): Delegation an rapt.get_my_rapt_creds.
-- Liest nicht mehr aus aibrewgenius.user_profiles.rapt_secret_id,
-- sondern aus dem rapt-Store. Hard-Drop in späterer Aufräum-Migration.
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delegation: rapt.get_my_rapt_creds() filtert intern auf auth.uid().
  RETURN QUERY SELECT r.username, r.api_key FROM rapt.get_my_rapt_creds() r;
END $$;

-- Grants unverändernd belassen (idempotent)
REVOKE EXECUTE ON FUNCTION aibrewgenius.get_my_rapt_creds() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION aibrewgenius.get_my_rapt_creds() TO authenticated;

-- ---------------------------------------------------------------------------
-- STEP 4: rapt_secret_id + rapt_configured in aibrewgenius.user_profiles deprecaten
-- ---------------------------------------------------------------------------
-- Spalten werden NICHT gedroppt (Generated-Column-Drop + FK-Drop = Client-Bruch-Risiko;
-- spätere Aufräum-Migration macht das explizit).
-- Nach Step 1 ist rapt_secret_id für alle Rows NULL → rapt_configured = false.
-- Clients müssen rapt_configured aus rapt.user_profiles lesen (flutter-coder-Handoff).
-- ---------------------------------------------------------------------------
COMMENT ON COLUMN aibrewgenius.user_profiles.rapt_secret_id IS
  'DEPRECATED Phase 1 (006_retire_aibrewgenius_rapt.sql): RAPT-Creds leben jetzt im '
  'rapt-Schema (rapt.user_profiles + vault.secrets). Diese Spalte ist ab Phase 1 immer NULL. '
  'Hard-Drop in späterer Aufräum-Migration.';

COMMENT ON COLUMN aibrewgenius.user_profiles.rapt_configured IS
  'DEPRECATED Phase 1 (006_retire_aibrewgenius_rapt.sql): Immer false, weil rapt_secret_id '
  'NULL ist. rapt_configured-Flag für RAPT aus rapt.user_profiles lesen (rapt-Schema, RLS-mediiert). '
  'Hard-Drop in späterer Aufräum-Migration.';

COMMIT;

-- =============================================================================
-- Sanity Checks (ausserhalb der Transaktion, read-only)
-- =============================================================================
\echo ''
\echo '== STEP 1 Verifikation: aibrewgenius rapt_secret_id soll NULL sein =='
SELECT
  id,
  rapt_user_id,
  rapt_secret_id IS NOT NULL  AS abg_rapt_in_vault,
  rapt_configured             AS abg_rapt_configured
FROM aibrewgenius.user_profiles;

\echo ''
\echo '== STEP 1 Verifikation: rapt.user_profiles (kanonische Quelle) =='
SELECT
  id,
  rapt_user_id,
  rapt_secret_id IS NOT NULL  AS rapt_in_vault,
  rapt_configured
FROM rapt.user_profiles;

\echo ''
\echo '== STEP 2+3: Funktionen in aibrewgenius (sollen search_path="" haben) =='
SELECT proname, prosecdef, proconfig
FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname IN ('get_my_rapt_creds', 'set_my_rapt_creds',
                  'get_my_brewfather_creds', 'set_my_brewfather_creds');

\echo ''
\echo '== Brewfather-Smoke: Brewfather-Funktionen unverändert =='
SELECT proname FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname IN ('get_my_brewfather_creds', 'set_my_brewfather_creds');

\echo ''
\echo '== Vault: rapt_-Eintraege (rapt_dash_<uuid> = rapt-Schema-Namespace, erwartet: vorhanden) =='
SELECT name, description FROM vault.secrets WHERE name LIKE 'rapt%' ORDER BY created_at;
