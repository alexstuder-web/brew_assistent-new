-- =============================================================================
-- Migration 009: Drop aibrewgenius RAPT delegation shims
-- =============================================================================
-- Context:
--   Migrations 006 retired aibrewgenius.get_my_rapt_creds() and
--   aibrewgenius.set_my_rapt_creds(text) by turning them into delegation shims
--   that forwarded calls to rapt.get_my_rapt_creds() / rapt.set_my_rapt_creds().
--
--   Migration 008 dropped all RAPT columns from aibrewgenius.user_profiles
--   (rapt_configured, rapt_secret_id, rapt_user_id, rapt_api_key).
--
-- Preflight verification (executed before writing this migration):
--   grep brew-proxy-new/**/*.js    → server.js line 1081:
--       callMyCredsRpc(jwt, 'get_my_rapt_creds', 'rapt')
--       Content-Profile = 'rapt'  → rapt schema, NOT aibrewgenius.
--   grep brew_assistent-new/**/*.dart → user_profile_service.dart line 88:
--       .schema('rapt').rpc('set_my_rapt_creds', ...)
--       schema = 'rapt'            → rapt schema, NOT aibrewgenius.
--   grep RAPT_Brewing_Dashboard-new/**/*.dart → rapt_repository.dart line 231:
--       _client.schema('rapt').rpc('set_my_rapt_creds', ...)
--       schema = 'rapt'            → rapt schema, NOT aibrewgenius.
--   brew_session.dart line 138: comment only, no call.
--
--   Result: 0 callers use aibrewgenius Content-Profile for RAPT RPCs.
--   The shims are dead code. Safe to drop.
--
-- What this migration does:
--   DROP FUNCTION IF EXISTS aibrewgenius.get_my_rapt_creds()
--   DROP FUNCTION IF EXISTS aibrewgenius.set_my_rapt_creds(text)
--
-- What this migration does NOT touch:
--   aibrewgenius.get_my_brewfather_creds()   — actively used, untouched.
--   aibrewgenius.set_my_brewfather_creds(text) — actively used, untouched.
--   rapt.get_my_rapt_creds()                 — canonical, untouched.
--   rapt.set_my_rapt_creds(text, text)       — canonical, untouched.
--   All other aibrewgenius tables and RPCs.
--
-- Idempotent: IF EXISTS guards; running twice is a no-op.
-- Runs as supabase_admin (owner of aibrewgenius schema objects).
-- =============================================================================

BEGIN;

DROP FUNCTION IF EXISTS aibrewgenius.get_my_rapt_creds();
DROP FUNCTION IF EXISTS aibrewgenius.set_my_rapt_creds(text);

COMMIT;

-- =============================================================================
-- Sanity checks (outside transaction; read-only)
-- =============================================================================
\echo ''
\echo '== 009: aibrewgenius rapt shims must be absent =='
SELECT proname
FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname IN ('get_my_rapt_creds', 'set_my_rapt_creds');
-- Expected: 0 rows

\echo ''
\echo '== 009: aibrewgenius Brewfather RPCs must still exist =='
SELECT proname, prosecdef, proconfig
FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname IN ('get_my_brewfather_creds', 'set_my_brewfather_creds')
ORDER BY proname;
-- Expected: 2 rows, prosecdef = true

\echo ''
\echo '== 009: rapt schema RPCs must still exist =='
SELECT proname
FROM pg_proc
WHERE pronamespace = 'rapt'::regnamespace
  AND proname IN ('get_my_rapt_creds', 'set_my_rapt_creds', 'get_all_rapt_creds_for_sync')
ORDER BY proname;
-- Expected: 3 rows
