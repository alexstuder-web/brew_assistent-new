-- =============================================================================
-- Migration 003: API-Keys via Supabase Vault verschlüsseln
-- =============================================================================
-- brewfather_api_key + rapt_api_key (Klartext in user_profiles) werden in
-- vault.secrets verschoben. user_profiles referenziert die Vault-Row über
-- brewfather_secret_id / rapt_secret_id (uuid). Die Klartext-Spalten bleiben
-- erhalten, werden aber genullt und nicht mehr beschrieben (siehe RPC unten).
--
-- Frontend/Proxy sehen den entschlüsselten Wert nur über die SECURITY DEFINER
-- Funktionen aibrewgenius.get_my_*_creds(). Diese laufen als Owner (supabase_admin)
-- und prüfen intern auth.uid() — ein User kann nur die EIGENEN Creds bekommen.
--
-- DB-Backups (pg_dump) enthalten ab jetzt nur noch die verschlüsselten Secrets
-- aus vault.secrets, nicht mehr die Klartext-Werte.
--
-- Schritte (alles in einer Transaktion):
--   1. Spalten brewfather_secret_id, rapt_secret_id (uuid) hinzufügen
--   2. Computed columns brewfather_configured, rapt_configured (boolean)
--      damit das Frontend ohne Decrypt-Recht das "is configured?"-Flag lesen kann
--   3. Bestehende Klartext-Keys nach vault.secrets migrieren, secret_id setzen,
--      Klartext-Spalten nullen
--   4. SECURITY DEFINER Funktionen für GET + SET der Creds
--   5. GRANT EXECUTE auf authenticated
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Neue Spalten
-- ---------------------------------------------------------------------------
ALTER TABLE aibrewgenius.user_profiles
  ADD COLUMN IF NOT EXISTS brewfather_secret_id uuid REFERENCES vault.secrets(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS rapt_secret_id        uuid REFERENCES vault.secrets(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------------
-- 2. Computed Configured-Flags (READ-only)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'aibrewgenius' AND table_name = 'user_profiles' AND column_name = 'brewfather_configured'
  ) THEN
    ALTER TABLE aibrewgenius.user_profiles
      ADD COLUMN brewfather_configured boolean GENERATED ALWAYS AS (brewfather_secret_id IS NOT NULL) STORED;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'aibrewgenius' AND table_name = 'user_profiles' AND column_name = 'rapt_configured'
  ) THEN
    ALTER TABLE aibrewgenius.user_profiles
      ADD COLUMN rapt_configured boolean GENERATED ALWAYS AS (rapt_secret_id IS NOT NULL) STORED;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Bestehende Klartext-Keys nach vault.secrets migrieren
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_secret_id uuid;
BEGIN
  FOR r IN
    SELECT id, brewfather_api_key, rapt_api_key, brewfather_secret_id, rapt_secret_id
    FROM aibrewgenius.user_profiles
  LOOP
    -- Brewfather
    IF r.brewfather_api_key IS NOT NULL AND r.brewfather_api_key <> '' AND r.brewfather_secret_id IS NULL THEN
      v_secret_id := vault.create_secret(
        new_secret      => r.brewfather_api_key,
        new_name        => 'bf_' || r.id::text,
        new_description => 'Brewfather API key for user ' || r.id::text
      );
      UPDATE aibrewgenius.user_profiles
      SET brewfather_secret_id = v_secret_id,
          brewfather_api_key   = NULL
      WHERE id = r.id;
      RAISE NOTICE 'Migrated Brewfather key for user %: secret_id=%', r.id, v_secret_id;
    END IF;

    -- RAPT
    IF r.rapt_api_key IS NOT NULL AND r.rapt_api_key <> '' AND r.rapt_secret_id IS NULL THEN
      v_secret_id := vault.create_secret(
        new_secret      => r.rapt_api_key,
        new_name        => 'rapt_' || r.id::text,
        new_description => 'RAPT API key for user ' || r.id::text
      );
      UPDATE aibrewgenius.user_profiles
      SET rapt_secret_id = v_secret_id,
          rapt_api_key   = NULL
      WHERE id = r.id;
      RAISE NOTICE 'Migrated RAPT key for user %: secret_id=%', r.id, v_secret_id;
    END IF;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 4. SECURITY DEFINER Funktionen für Lese-Zugriff (vom Proxy genutzt)
-- ---------------------------------------------------------------------------
-- get_my_brewfather_creds(): liefert die entschlüsselten Brewfather-Creds des
-- aktuellen Users. Sicher, weil:
--   - SECURITY DEFINER -> läuft als supabase_admin (kann vault.decrypted_secrets lesen)
--   - filtert intern auf auth.uid() -> User sieht nur seine eigenen Creds
--   - search_path locked -> kein Schema-Injection
CREATE OR REPLACE FUNCTION aibrewgenius.get_my_brewfather_creds()
RETURNS TABLE (user_id text, api_key text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aibrewgenius, vault, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_secret_id uuid;
  v_user_id text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT up.brewfather_user_id, up.brewfather_secret_id
    INTO v_user_id, v_secret_id
  FROM aibrewgenius.user_profiles up
  WHERE up.id = v_uid;

  IF v_secret_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT v_user_id, ds.decrypted_secret::text
    FROM vault.decrypted_secrets ds
    WHERE ds.id = v_secret_id;
END $$;

CREATE OR REPLACE FUNCTION aibrewgenius.get_my_rapt_creds()
RETURNS TABLE (username text, api_key text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aibrewgenius, vault, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_secret_id uuid;
  v_username text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT up.rapt_user_id, up.rapt_secret_id
    INTO v_username, v_secret_id
  FROM aibrewgenius.user_profiles up
  WHERE up.id = v_uid;

  IF v_secret_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
    SELECT v_username, ds.decrypted_secret::text
    FROM vault.decrypted_secrets ds
    WHERE ds.id = v_secret_id;
END $$;

-- ---------------------------------------------------------------------------
-- 5. SECURITY DEFINER Funktionen für Schreib-Zugriff (vom Frontend genutzt)
-- ---------------------------------------------------------------------------
-- set_my_brewfather_creds(api_key text):
--   - api_key non-empty -> create-or-update vault secret, secret_id setzen
--   - api_key NULL oder '' -> secret_id auf NULL, vault.secrets-Row löschen
CREATE OR REPLACE FUNCTION aibrewgenius.set_my_brewfather_creds(p_api_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aibrewgenius, vault, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_secret_id uuid;
  v_new_secret_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT up.brewfather_secret_id INTO v_secret_id
  FROM aibrewgenius.user_profiles up
  WHERE up.id = v_uid;

  IF p_api_key IS NULL OR p_api_key = '' THEN
    -- Clear: secret_id auf NULL, alte Vault-Row löschen
    IF v_secret_id IS NOT NULL THEN
      UPDATE aibrewgenius.user_profiles SET brewfather_secret_id = NULL WHERE id = v_uid;
      DELETE FROM vault.secrets WHERE id = v_secret_id;
    END IF;
    RETURN;
  END IF;

  IF v_secret_id IS NULL THEN
    v_new_secret_id := vault.create_secret(
      new_secret      => p_api_key,
      new_name        => 'bf_' || v_uid::text,
      new_description => 'Brewfather API key for user ' || v_uid::text
    );
    UPDATE aibrewgenius.user_profiles SET brewfather_secret_id = v_new_secret_id WHERE id = v_uid;
  ELSE
    PERFORM vault.update_secret(secret_id => v_secret_id, new_secret => p_api_key);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION aibrewgenius.set_my_rapt_creds(p_api_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aibrewgenius, vault, pg_catalog
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_secret_id uuid;
  v_new_secret_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT up.rapt_secret_id INTO v_secret_id
  FROM aibrewgenius.user_profiles up
  WHERE up.id = v_uid;

  IF p_api_key IS NULL OR p_api_key = '' THEN
    IF v_secret_id IS NOT NULL THEN
      UPDATE aibrewgenius.user_profiles SET rapt_secret_id = NULL WHERE id = v_uid;
      DELETE FROM vault.secrets WHERE id = v_secret_id;
    END IF;
    RETURN;
  END IF;

  IF v_secret_id IS NULL THEN
    v_new_secret_id := vault.create_secret(
      new_secret      => p_api_key,
      new_name        => 'rapt_' || v_uid::text,
      new_description => 'RAPT API key for user ' || v_uid::text
    );
    UPDATE aibrewgenius.user_profiles SET rapt_secret_id = v_new_secret_id WHERE id = v_uid;
  ELSE
    PERFORM vault.update_secret(secret_id => v_secret_id, new_secret => p_api_key);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 6. Permissions
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION aibrewgenius.get_my_brewfather_creds() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION aibrewgenius.get_my_rapt_creds()       FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION aibrewgenius.set_my_brewfather_creds(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION aibrewgenius.set_my_rapt_creds(text)       FROM PUBLIC;

GRANT EXECUTE ON FUNCTION aibrewgenius.get_my_brewfather_creds() TO authenticated;
GRANT EXECUTE ON FUNCTION aibrewgenius.get_my_rapt_creds()       TO authenticated;
GRANT EXECUTE ON FUNCTION aibrewgenius.set_my_brewfather_creds(text) TO authenticated;
GRANT EXECUTE ON FUNCTION aibrewgenius.set_my_rapt_creds(text)       TO authenticated;

-- Klartext-Spalten brewfather_api_key / rapt_api_key bleiben im Schema, sind
-- aber jetzt überall NULL. Nicht droppen (würde Apps brechen, die noch alte
-- INSERT/UPDATE-Statements absetzen). Ab jetzt: niemand mehr beschreibt sie.

COMMIT;

-- =============================================================================
-- Sanity Checks
-- =============================================================================
\echo ''
\echo '== Vault-Inhalt =='
SELECT name, description, created_at FROM vault.secrets ORDER BY created_at;

\echo ''
\echo '== user_profiles state =='
SELECT
  id,
  brewfather_user_id,
  brewfather_secret_id IS NOT NULL AS bf_in_vault,
  brewfather_configured,
  brewfather_api_key IS NULL AS bf_clear_nulled,
  rapt_user_id,
  rapt_secret_id IS NOT NULL AS rapt_in_vault,
  rapt_configured,
  rapt_api_key IS NULL AS rapt_clear_nulled
FROM aibrewgenius.user_profiles;

\echo ''
\echo '== Function test (run as supabase_admin -> auth.uid() will be NULL, just shows function exists) =='
SELECT proname FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname IN ('get_my_brewfather_creds', 'get_my_rapt_creds', 'set_my_brewfather_creds', 'set_my_rapt_creds');
