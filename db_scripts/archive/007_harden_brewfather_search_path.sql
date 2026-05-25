-- =============================================================================
-- Migration 007: search_path-Härtung für SECURITY DEFINER-Funktionen
-- =============================================================================
-- Reine Sicherheits-Härtung, KEINE Verhaltensänderung.
--
-- Betroffen:
--   1. aibrewgenius.get_my_brewfather_creds()
--      003_vault.sql: SET search_path = aibrewgenius, vault, pg_catalog
--      → SET search_path = '' + voll-qualifizierte Objekte
--
--   2. aibrewgenius.set_my_brewfather_creds(text)
--      003_vault.sql: SET search_path = aibrewgenius, vault, pg_catalog
--      → SET search_path = '' + voll-qualifizierte Objekte
--
--   3. aibrewgenius.handle_new_user()  [BONUS]
--      002_auth.sql: SET search_path = aibrewgenius, public
--      → SET search_path = '' + voll-qualifizierte Objekte
--
-- Nicht betroffen:
--   - aibrewgenius.get_my_rapt_creds()    — bereits in 006 auf '' gesetzt
--   - aibrewgenius.set_my_rapt_creds(text)— bereits in 006 auf '' gesetzt
--   - aibrewgenius.set_updated_at()       — KEIN SECURITY DEFINER; Trigger-Funktion,
--                                           läuft als Invoker; kein Privilege-Boundary
--
-- Idempotent: CREATE OR REPLACE ersetzt die vorhandene Definition ohne Fehler.
-- Zweimaliges Anwenden produziert kein Error und ändert nichts am Verhalten.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. aibrewgenius.get_my_brewfather_creds()
--    Liefert die entschlüsselten Brewfather-Creds des aktuellen Users.
--    Logik identisch zu 003_vault.sql, nur search_path='' und alle Objekte
--    voll-qualifiziert.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aibrewgenius.get_my_brewfather_creds()
RETURNS TABLE (user_id text, api_key text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_secret_id uuid;
  v_user_id   text;
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

REVOKE EXECUTE ON FUNCTION aibrewgenius.get_my_brewfather_creds() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION aibrewgenius.get_my_brewfather_creds() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. aibrewgenius.set_my_brewfather_creds(text)
--    Schreibt/überschreibt/löscht den Brewfather-Key im Vault.
--    Logik identisch zu 003_vault.sql, nur search_path='' und alle Objekte
--    voll-qualifiziert.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aibrewgenius.set_my_brewfather_creds(p_api_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid           uuid := auth.uid();
  v_secret_id     uuid;
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
      UPDATE aibrewgenius.user_profiles
        SET brewfather_secret_id = NULL
      WHERE id = v_uid;
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
    UPDATE aibrewgenius.user_profiles
      SET brewfather_secret_id = v_new_secret_id
    WHERE id = v_uid;
  ELSE
    PERFORM vault.update_secret(secret_id => v_secret_id, new_secret => p_api_key);
  END IF;
END $$;

REVOKE EXECUTE ON FUNCTION aibrewgenius.set_my_brewfather_creds(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION aibrewgenius.set_my_brewfather_creds(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. aibrewgenius.handle_new_user()  [BONUS]
--    Trigger-Funktion: neuer auth.users-Row -> user_profiles-Row anlegen.
--    Logik identisch zu 002_auth.sql, nur search_path='' und alle Objekte
--    (aibrewgenius.user_profiles, split_part aus pg_catalog) voll-qualifiziert.
--    split_part ist ein pg_catalog-Builtin; ohne search_path muss es via
--    pg_catalog.split_part aufgerufen werden.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aibrewgenius.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO aibrewgenius.user_profiles (id, name, language, brewfather_sync_enabled)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', pg_catalog.split_part(NEW.email, '@', 1)),
    'de',
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $$;

-- Trigger-Funktion braucht kein EXECUTE-Grant (wird vom Trigger-Owner aufgerufen,
-- nicht direkt von authenticated). Zur Sicherheit PUBLIC dennoch entziehen.
REVOKE EXECUTE ON FUNCTION aibrewgenius.handle_new_user() FROM PUBLIC;

COMMIT;

-- =============================================================================
-- Sanity Checks (außerhalb der Transaktion; read-only)
-- =============================================================================
\echo ''
\echo '== 007: proconfig-Check — alle drei Funktionen sollen search_path="" zeigen =='
SELECT
  p.proname,
  p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'aibrewgenius'
  AND p.proname IN (
    'get_my_brewfather_creds',
    'set_my_brewfather_creds',
    'handle_new_user'
  )
ORDER BY p.proname;

\echo ''
\echo '== 007: Vollständiger SECURITY DEFINER + search_path-Audit im aibrewgenius-Schema =='
SELECT
  p.proname,
  p.prosecdef          AS security_definer,
  p.proconfig          AS proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'aibrewgenius'
  AND p.prosecdef = true
ORDER BY p.proname;
