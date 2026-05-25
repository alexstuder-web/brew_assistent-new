-- =============================================================================
-- Migration 008: Drop dead RAPT columns from aibrewgenius.user_profiles
-- =============================================================================
-- Context:
--   After the RAPT-Multi-Tenant-Epic (Phase 1/2) the canonical RAPT-cred source
--   is rapt.user_profiles + vault.secrets (rapt_dash_<uuid> namespace).
--   Migration 006 retired the aibrewgenius RAPT RPCs by delegation and zeroed
--   every rapt_secret_id row.  This migration does the hard drop.
--
-- Pre-flight check (verified before writing):
--   * rapt_secret_id IS NULL for all rows → no live vault FK reference.
--   * No views reference any of the four columns being dropped.
--   * vault.secrets contains only rapt_dash_<uuid> entries (rapt-schema namespace)
--     and bf_<uuid> entries (Brewfather).  No rapt_<uuid> (old aibrewgenius
--     namespace) orphans exist → vault cleanup block will be a no-op.
--   * get_my_rapt_creds() already delegates fully to rapt.get_my_rapt_creds();
--     it does NOT read any of the dropped columns → no change needed there.
--   * set_my_rapt_creds() reads rapt_user_id from aibrewgenius.user_profiles
--     as its first lookup before falling back to rapt.user_profiles.
--     Dropping rapt_user_id without fixing this function would cause a runtime
--     error on the next call.  Step 1 replaces the function to read solely from
--     rapt.user_profiles first (single canonical source), then proceeds to drop.
--
-- Drop order (dependency chain):
--   1. rapt_configured  (GENERATED ALWAYS AS rapt_secret_id IS NOT NULL — must
--                        go before rapt_secret_id or Postgres will reject the drop)
--   2. rapt_secret_id   (FK → vault.secrets; FK constraint dropped automatically)
--   3. rapt_user_id     (plain text — no dependents after step 1 fixes the RPC)
--   4. rapt_api_key     (plain text, already NULL everywhere since 003_vault.sql)
--
-- Brewfather columns are NOT touched:
--   brewfather_user_id, brewfather_api_key, brewfather_secret_id,
--   brewfather_configured, brewfather_sync_enabled.
--
-- Idempotent: all DDL uses IF EXISTS; function uses CREATE OR REPLACE.
-- Runs as supabase_admin (owner of aibrewgenius schema objects).
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- STEP 1: Replace aibrewgenius.set_my_rapt_creds to remove the read of
--         aibrewgenius.user_profiles.rapt_user_id (column being dropped).
--
--         New logic: read rapt_user_id exclusively from rapt.user_profiles
--         (the canonical source since Phase 1).  If no rapt-profile row exists
--         yet, pass NULL — rapt.set_my_rapt_creds handles that gracefully.
--
--         All other security properties preserved:
--           - SECURITY DEFINER
--           - SET search_path = ''
--           - auth.uid() NULL-check (defense in depth; rapt RPC re-checks too)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aibrewgenius.set_my_rapt_creds(p_api_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
-- DEPRECATED compat shim (006_retire_aibrewgenius_rapt.sql).
-- Delegates to rapt.set_my_rapt_creds; reads rapt_user_id solely from
-- rapt.user_profiles (aibrewgenius.user_profiles.rapt_user_id was dropped
-- in 008_drop_aibrewgenius_rapt_columns.sql).
-- Canonical call path: rapt.set_my_rapt_creds(rapt_user_id, api_key) directly.
DECLARE
  v_uid          uuid := auth.uid();
  v_rapt_user_id text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Read rapt_user_id from the canonical source (rapt schema).
  -- If the user has no rapt-profile row yet, v_rapt_user_id stays NULL;
  -- rapt.set_my_rapt_creds accepts NULL and will create/update the row.
  SELECT up.rapt_user_id
    INTO v_rapt_user_id
  FROM rapt.user_profiles up
  WHERE up.id = v_uid;

  -- Delegation: auth.uid() session context is preserved (PostgREST sets
  -- request.jwt.claims session-wide; rapt.set_my_rapt_creds re-checks internally).
  PERFORM rapt.set_my_rapt_creds(v_rapt_user_id, p_api_key);
END $$;

-- Grants unchanged (idempotent)
REVOKE EXECUTE ON FUNCTION aibrewgenius.set_my_rapt_creds(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION aibrewgenius.set_my_rapt_creds(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- STEP 2: Vault orphan cleanup
--         Delete any vault.secrets rows whose name matches the OLD aibrewgenius
--         RAPT namespace ('rapt_<uuid>' — NOT 'rapt_dash_<uuid>') that are no
--         longer referenced by any aibrewgenius.user_profiles.rapt_secret_id
--         (which is already NULL for all rows since 006).
--
--         'bf_<uuid>' (Brewfather) and 'rapt_dash_<uuid>' (rapt-schema) are
--         explicitly excluded.  Pre-flight verified there are no such orphans
--         on the current DB; this block runs as a safe no-op in that case.
--
--         Idempotency guard: if rapt_secret_id has already been dropped
--         (migration run a second time) we skip the referential check and
--         simply delete any name-matching secrets unconditionally — after the
--         column is gone there can be no live references to them anyway.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_deleted integer;
  v_col_exists boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'aibrewgenius'
      AND table_name   = 'user_profiles'
      AND column_name  = 'rapt_secret_id'
  ) INTO v_col_exists;

  IF v_col_exists THEN
    -- Column still present: delete old-namespace secrets not referenced by any row.
    DELETE FROM vault.secrets s
    WHERE s.name ~ '^rapt_[0-9a-f]{8}-'   -- matches 'rapt_<uuid>' pattern
      AND s.name NOT LIKE 'rapt\_dash\_%'  -- excludes rapt-schema namespace
      AND NOT EXISTS (
        SELECT 1
        FROM aibrewgenius.user_profiles up
        WHERE up.rapt_secret_id = s.id
      );
  ELSE
    -- Column already dropped (second run): no live FK references possible;
    -- delete any remaining old-namespace secrets unconditionally.
    DELETE FROM vault.secrets s
    WHERE s.name ~ '^rapt_[0-9a-f]{8}-'
      AND s.name NOT LIKE 'rapt\_dash\_%';
  END IF;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  IF v_deleted > 0 THEN
    RAISE NOTICE 'STEP 2: Deleted % orphaned aibrewgenius-namespace RAPT vault secret(s).', v_deleted;
  ELSE
    RAISE NOTICE 'STEP 2: No orphaned aibrewgenius-namespace RAPT vault secrets found — no-op.';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- STEP 3: Drop the dead RAPT columns from aibrewgenius.user_profiles
--
--   Order matters:
--     a) rapt_configured first — it is GENERATED ALWAYS AS (rapt_secret_id IS NOT NULL);
--        Postgres will refuse to drop rapt_secret_id while a generated column
--        depends on it.
--     b) rapt_secret_id second — drops the FK constraint user_profiles_rapt_secret_id_fkey
--        automatically (ON DELETE SET NULL means the FK object itself is attached
--        to this column).
--     c) rapt_user_id third — plain text; now safe after Step 1 removed the
--        last function reference.
--     d) rapt_api_key last — plain text, NULL everywhere since 003_vault.sql.
-- ---------------------------------------------------------------------------
ALTER TABLE aibrewgenius.user_profiles
  DROP COLUMN IF EXISTS rapt_configured;   -- (a) GENERATED column; no cascade needed

ALTER TABLE aibrewgenius.user_profiles
  DROP COLUMN IF EXISTS rapt_secret_id;    -- (b) FK to vault.secrets; constraint auto-dropped

ALTER TABLE aibrewgenius.user_profiles
  DROP COLUMN IF EXISTS rapt_user_id;      -- (c) plain text; RPC no longer references it

ALTER TABLE aibrewgenius.user_profiles
  DROP COLUMN IF EXISTS rapt_api_key;      -- (d) plain text; NULL since 003

COMMIT;

-- =============================================================================
-- Sanity checks (outside transaction; read-only)
-- =============================================================================
\echo ''
\echo '== 008: user_profiles columns — rapt_* must be absent, brewfather_* intact =='
SELECT column_name, data_type, is_generated
FROM information_schema.columns
WHERE table_schema = 'aibrewgenius' AND table_name = 'user_profiles'
ORDER BY ordinal_position;

\echo ''
\echo '== 008: FK constraints on user_profiles — rapt_secret_id FK must be gone =='
SELECT tc.constraint_name, kcu.column_name, ccu.table_name AS foreign_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'aibrewgenius'
  AND tc.table_name = 'user_profiles'
  AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.constraint_name;

\echo ''
\echo '== 008: set_my_rapt_creds body — must NOT reference aibrewgenius.user_profiles.rapt_user_id =='
SELECT proname, prosrc
FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname = 'set_my_rapt_creds';

\echo ''
\echo '== 008: get_my_rapt_creds — delegation intact, no rapt column references =='
SELECT proname, prosrc
FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname = 'get_my_rapt_creds';

\echo ''
\echo '== 008: Brewfather RPCs — must still exist and be unchanged =='
SELECT proname, prosecdef, proconfig
FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname IN ('get_my_brewfather_creds', 'set_my_brewfather_creds')
ORDER BY proname;

\echo ''
\echo '== 008: vault.secrets — only rapt_dash_* and bf_* expected; no rapt_<uuid> orphans =='
SELECT name, description FROM vault.secrets ORDER BY created_at;
