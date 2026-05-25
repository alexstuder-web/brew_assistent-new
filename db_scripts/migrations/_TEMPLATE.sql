-- =============================================================================
-- NNN_<short_description>.sql  — aibrewgenius migration template
-- =============================================================================
-- Version:  NNN   (3-digit numeric string, e.g. 001, 010, 100)
-- Purpose:  <One sentence: what this migration changes and why>
-- Schema:   aibrewgenius  (default PostgREST schema; client impact: flag flutter-coder
--           on any column drop / rename / return-shape change)
-- Tables:   <list affected tables>
-- Author:   dba-coder  — applied as supabase_admin
-- Date:     YYYY-MM-DD
--
-- Rules (mandatory — do not remove this block):
--   - Forward-only.  NEVER edit this file once applied to any live DB.
--     Fix-forward with a NEW migration (next number up).
--   - Idempotent: CREATE TABLE IF NOT EXISTS, CREATE OR REPLACE FUNCTION,
--     ADD COLUMN IF NOT EXISTS, DROP POLICY IF EXISTS + CREATE POLICY,
--     CREATE INDEX IF NOT EXISTS.
--   - DDL runs as supabase_admin (the runner connects as supabase_admin).
--   - The schema_migrations INSERT is INSIDE the same transaction — a DDL
--     error rolls back the version row too, keeping the DB consistent.
--
-- RLS / SECURITY DEFINER checklist (delete items that do not apply):
--   [ ] Every new user-facing table has ALTER TABLE … ENABLE ROW LEVEL SECURITY
--       AND at least one policy. (Enabled with no policy = nobody can read.)
--   [ ] Policies filter on auth.uid() — NEVER USING (true) on tenant data.
--   [ ] Write policies carry a WITH CHECK clause (separate from USING).
--   [ ] New indexes on every user_profile_id / owner FK column RLS filters on.
--   [ ] SECURITY DEFINER functions have SET search_path = '' AND re-assert
--       auth.uid() filter internally (RLS is bypassed for them).
--   [ ] New API keys go into vault.secrets, not plaintext columns.
--       Add vault slot + generated *_configured flag + get/set RPCs.
--   [ ] GRANT least-privilege: authenticated gets SELECT/INSERT/UPDATE/DELETE
--       where RLS guards rows; never bypass RLS with BYPASSRLS or a role
--       that owns the table.
-- =============================================================================

BEGIN;

SET statement_timeout = 0;
SET lock_timeout = 0;
SELECT pg_catalog.set_config('search_path', '', false);
SET client_min_messages = warning;

-- ---------------------------------------------------------------------------
-- Replace this block with the actual DDL for this migration.
-- ---------------------------------------------------------------------------

-- Example: add a column
-- ALTER TABLE aibrewgenius.some_table
--   ADD COLUMN IF NOT EXISTS new_col text;

-- Example: new table with RLS
-- CREATE TABLE IF NOT EXISTS aibrewgenius.new_table (
--   id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
--   user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
--   name            text        NOT NULL,
--   created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
--   updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
-- );
-- ALTER TABLE aibrewgenius.new_table OWNER TO supabase_admin;
-- CREATE INDEX IF NOT EXISTS idx_abg_new_table_upid
--   ON aibrewgenius.new_table (user_profile_id);
-- ALTER TABLE aibrewgenius.new_table ENABLE ROW LEVEL SECURITY;
-- DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.new_table;
-- CREATE POLICY user_owns_rows ON aibrewgenius.new_table
--   FOR ALL TO authenticated
--   USING (user_profile_id = auth.uid())
--   WITH CHECK (user_profile_id = auth.uid());
-- GRANT SELECT, INSERT, UPDATE, DELETE ON aibrewgenius.new_table TO authenticated;
-- GRANT ALL ON aibrewgenius.new_table TO service_role;

-- Example: SECURITY DEFINER function (always pinned search_path, always auth.uid() filter)
-- CREATE OR REPLACE FUNCTION aibrewgenius.my_rpc()
-- RETURNS text
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = ''
-- AS $$
-- DECLARE v_uid uuid := auth.uid();
-- BEGIN
--   IF v_uid IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
--   -- ... logic filtered on v_uid ...
-- END $$;
-- ALTER FUNCTION aibrewgenius.my_rpc() OWNER TO supabase_admin;
-- REVOKE EXECUTE ON FUNCTION aibrewgenius.my_rpc() FROM PUBLIC;
-- GRANT  EXECUTE ON FUNCTION aibrewgenius.my_rpc() TO authenticated;

-- ---------------------------------------------------------------------------
-- schema_migrations version anchor — MUST be last, inside this transaction.
-- Replace NNN with the actual 3-digit version string (same as the filename).
-- ON CONFLICT DO NOTHING makes re-apply a safe no-op.
-- ---------------------------------------------------------------------------
INSERT INTO public.schema_migrations (version, applied_at)
VALUES ('NNN', now())
ON CONFLICT (version) DO NOTHING;

COMMIT;
