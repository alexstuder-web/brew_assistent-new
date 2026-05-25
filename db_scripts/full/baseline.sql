-- =============================================================================
-- baseline.sql — aibrewgenius Per-App Init-Baseline (Clean Cut)
-- =============================================================================
-- Purpose:  Reproduce the complete aibrewgenius schema end-state on a FRESH
--           brew_assistent Supabase DB in a single apply. No historical
--           create-then-drop cycles; this is the tested target state directly.
--
-- Covered:  Equivalent to migrations 001–009 (aibrewgenius only), RAPT-free.
--           - 001_init_schema     → schema + tables + indexes + triggers
--           - 002_auth            → RLS policies, handle_new_user trigger
--           - 003_vault           → Brewfather vault RPCs
--           - 004_proxy_role      → proxy_sync EXCLUDED (not needed in assistent-DB)
--           - 005_fix_proxy_role_grants → excluded (proxy_sync not here)
--           - 006_retire_aibrewgenius_rapt → RAPT dropped (never created)
--           - 007_harden_brewfather_search_path → already hardened here
--           - 008_drop_aibrewgenius_rapt_columns → RAPT columns never created
--           - 009_drop_aibrewgenius_rapt_shims → RAPT RPCs never created
--
-- schema_migrations contract (Phase-2 runner):
--   - Version format: 3-digit numeric string, e.g. '000', '001', '010'.
--   - This baseline inserts version '000' at the end to mark the clean-cut
--     starting point. All future migrations start at '001' and insert their
--     own version row at the end of their transaction.
--   - Phase-2 runner logic: apply all migrations where version > MAX(applied).
--     On a fresh DB (schema_migrations empty or missing version '000'):
--     apply baseline first, then run numbered migrations in order.
--   - Baseline re-apply: idempotent (CREATE IF NOT EXISTS, OR REPLACE, etc.).
--     INSERT ON CONFLICT DO NOTHING for the schema_migrations row.
--
-- EXCLUDED intentionally:
--   - proxy_sync role/grants: db-sync only writes rapt-schema → proxy_sync
--     lives exclusively in the rapt-DB. cicd-handoff: assistent zz-set-role-
--     passwords.sh MUST NOT create proxy_sync (already confirmed in current
--     webPage_infra/supabase/db_init_assistent/zz-set-role-passwords.sh).
--   - RAPT-related columns/RPCs (rapt_secret_id, rapt_configured,
--     get_my_rapt_creds, set_my_rapt_creds): per-app-DB pivot Entscheidung 2+7.
--   - Seed data (aibrewgenius_seed.sql is dev-only, not part of baseline).
--   - Bootstrap user: handle_new_user trigger creates user_profiles rows
--     automatically on every auth.users INSERT.
--
-- Prerequisites (provided by supabase/postgres image + zz-set-role-passwords.sh):
--   - Extensions: pgcrypto, pgjwt, supabase_vault, uuid-ossp
--   - Roles: anon, authenticated, service_role, supabase_admin
--   - vault.secrets + vault.decrypted_secrets + vault.create_secret/update_secret
--   - auth.users (GoTrue core)
--
-- Apply:
--   cat brew_assistent-new/db_scripts/full/baseline.sql \
--     | docker exec -i db-assistent psql -U supabase_admin -d postgres \
--         --variable=ON_ERROR_STOP=1
--
-- Idempotency:
--   Safe to apply twice on a fresh DB. CREATE TABLE IF NOT EXISTS,
--   CREATE OR REPLACE FUNCTION, DROP POLICY IF EXISTS + CREATE POLICY,
--   CREATE INDEX IF NOT EXISTS, CREATE TRIGGER OR REPLACE. The
--   schema_migrations INSERT uses ON CONFLICT DO NOTHING.
-- =============================================================================

BEGIN;

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- =============================================================================
-- SECTION 0: public.schema_migrations (Phase-2 runner anchor)
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version    text        PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.schema_migrations OWNER TO supabase_admin;
COMMENT ON TABLE public.schema_migrations IS
  'Phase-2 migrations runner tracking. '
  'Version format: 3-digit numeric string (000, 001, 010, ...). '
  'Baseline inserts 000. Each subsequent migration inserts its own version '
  'at the end of its transaction. Runner: apply where version > MAX(applied).';

-- =============================================================================
-- SECTION 1: aibrewgenius Schema
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS aibrewgenius;
ALTER SCHEMA aibrewgenius OWNER TO supabase_admin;

-- anon intentionally excluded: app is fully behind AuthGate; anon needs
-- no schema introspection rights on aibrewgenius.
REVOKE ALL ON SCHEMA aibrewgenius FROM PUBLIC;
GRANT USAGE ON SCHEMA aibrewgenius TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1a. set_updated_at — Trigger function (no SECURITY DEFINER needed)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aibrewgenius.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END
$$;
ALTER FUNCTION aibrewgenius.set_updated_at() OWNER TO supabase_admin;

-- ---------------------------------------------------------------------------
-- 1b. user_profiles
--     - brewfather_api_key: always NULL since 003_vault; kept for Compat
--     - brewfather_configured: GENERATED (brewfather_secret_id IS NOT NULL)
--     - NO rapt_* columns (per-app-DB pivot, Entscheidung 2+7)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS aibrewgenius.user_profiles (
  id                      uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name                    text,
  avatar_blob             text,
  default_batch_liters    double precision,
  brewfather_user_id      text,
  brewfather_api_key      text,           -- always NULL since 003_vault; kept for client compat
  brewfather_sync_enabled boolean         NOT NULL DEFAULT false,
  language                text,
  brewfather_secret_id    uuid            REFERENCES vault.secrets(id) ON DELETE SET NULL,
  brewfather_configured   boolean         GENERATED ALWAYS AS (brewfather_secret_id IS NOT NULL) STORED
);
ALTER TABLE aibrewgenius.user_profiles OWNER TO supabase_admin;

-- ---------------------------------------------------------------------------
-- 1c. Child tables
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS aibrewgenius.ai_generated_recipes_v2 (
  id                          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id             uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  basis_bier                  text,
  bier_typ                    text,
  stammwuerze_sg              double precision,
  restextrakt_sg              double precision,
  alkoholgehalt               double precision,
  notizen                     text[],
  generated_image             text,
  yeast_name                  text,
  yeast_type                  text,
  yeast_amount                text,
  yeast_procurement_needed    boolean,
  water_ca                    integer,
  water_mg                    integer,
  water_na                    integer,
  water_cl                    integer,
  water_so4                   integer,
  water_hco3                  integer,
  water_salt_timing           text,
  mash_water_l                double precision,
  mash_in_temp_c              double precision,
  lauter_sparge_water_l       double precision,
  lauter_target_ph            text,
  boil_pre_vol_l              double precision,
  boil_duration_min           integer,
  fermentation_pitch_temp_c   double precision,
  packaging_type              text,
  packaging_co2_target        double precision,
  packaging_keg_pressure      double precision,
  packaging_keg_temp          double precision,
  packaging_bottle_sugar      double precision,
  packaging_bottle_temp       double precision,
  packaging_storage_temp      double precision,
  packaging_storage_weeks     integer,
  packaging_maturation_note   text,
  packaging_serving_gas       text,
  packaging_carb_days         integer,
  can_pressurize              boolean     DEFAULT false,
  fermentation_pressure_note  text,
  bjcp_stil                   jsonb,
  ibu                         double precision,
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now(),
  malts                       jsonb       DEFAULT '[]'::jsonb,
  hops                        jsonb       DEFAULT '[]'::jsonb,
  specials                    jsonb       DEFAULT '[]'::jsonb,
  finings                     jsonb       DEFAULT '[]'::jsonb,
  mash_steps                  jsonb       DEFAULT '[]'::jsonb,
  fermentation_steps          jsonb       DEFAULT '[]'::jsonb
);
ALTER TABLE aibrewgenius.ai_generated_recipes_v2 OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.batches (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brewfather_id   text,
  name            text        NOT NULL,
  batch_no        integer,
  status          text,
  brew_date       bigint,
  recipe_name     text,
  analysis_data   jsonb,
  rapt_data       jsonb,
  data            jsonb,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.batches OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.brew_kettles (
  id                      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id         uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brand                   text        NOT NULL,
  model                   text,
  is_default              boolean     NOT NULL DEFAULT false,
  volume_liters           double precision,
  post_boil_loss_liters   double precision DEFAULT 0,
  boil_off_percentage     double precision DEFAULT 0,
  bh_efficiency           double precision DEFAULT 70,
  has_condenser_hat       boolean     NOT NULL DEFAULT false,
  notes                   text,
  created_at              timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at              timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.brew_kettles OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.fermentables (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brewfather_id   text,
  name            text        NOT NULL,
  supplier        text,
  amount          double precision,
  unit            text,
  type            text,
  potential       double precision,
  yield           double precision,
  attenuation     double precision,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.fermentables OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.fermenter_controllers (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  is_default      boolean     NOT NULL DEFAULT false,
  username        text,
  api_key         text,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.fermenter_controllers OWNER TO supabase_admin;
COMMENT ON COLUMN aibrewgenius.fermenter_controllers.api_key IS
  'Known deviation: device-controller API key stored in plaintext (not in vault). '
  'This key authenticates the local fermenter controller hardware, not a cloud API. '
  'Vault migration should be evaluated in a future migration if threat model requires it.';

CREATE TABLE IF NOT EXISTS aibrewgenius.fermenters (
  id                       uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id          uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brand                    text        NOT NULL,
  type                     text,
  is_default               boolean     NOT NULL DEFAULT false,
  volume_liters            double precision,
  has_heating              boolean     NOT NULL DEFAULT false,
  has_cooling              boolean     NOT NULL DEFAULT false,
  has_dry_hopping_port     boolean     NOT NULL DEFAULT false,
  can_pressurize           boolean     NOT NULL DEFAULT false,
  fermentation_loss_liters double precision NOT NULL DEFAULT 0,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at               timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.fermenters OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.fining_agents (
  user_profile_id  uuid        PRIMARY KEY REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  irish_moss       boolean     NOT NULL DEFAULT false,
  whirlfloc        boolean     NOT NULL DEFAULT false,
  gelatin          boolean     NOT NULL DEFAULT false,
  biersol          boolean     NOT NULL DEFAULT false,
  polyclar         boolean     NOT NULL DEFAULT false,
  isinglass        boolean     NOT NULL DEFAULT false,
  bentonite        boolean     NOT NULL DEFAULT false,
  egg_whites       boolean     NOT NULL DEFAULT false,
  activated_carbon boolean     NOT NULL DEFAULT false,
  extras           jsonb       NOT NULL DEFAULT '[]'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at       timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.fining_agents OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.hops (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brewfather_id   text,
  name            text        NOT NULL,
  alpha           double precision,
  origin          text,
  year            text,
  amount          double precision,
  unit            text,
  type            text,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.hops OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.how_to_topics (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  title           text        NOT NULL,
  content         text        DEFAULT '',
  pages           jsonb       DEFAULT '[]'::jsonb,
  position        integer     DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.how_to_topics OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.keezer_configs (
  user_profile_id uuid        PRIMARY KEY REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  num_taps        integer     DEFAULT 0,
  taps            jsonb       DEFAULT '[]'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.keezer_configs OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.malt_depots (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  url             text,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.malt_depots OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.miscs (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brewfather_id   text,
  name            text        NOT NULL,
  amount          double precision,
  unit            text,
  type            text,
  use             text,
  time            double precision,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.miscs OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.packaging_profiles (
  id                        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id           uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  name                      text        NOT NULL,
  target_volume             double precision,
  bottle_enabled            boolean     NOT NULL DEFAULT false,
  bottle_carbonation_temp_c double precision,
  bottle_storage_temp_c     double precision,
  keg_enabled               boolean     NOT NULL DEFAULT false,
  keg_carbonation_temp_c    double precision,
  keg_storage_temp_c        double precision,
  keg_volume_l              double precision,
  has_co2                   boolean     NOT NULL DEFAULT true,
  has_nitro                 boolean     NOT NULL DEFAULT false,
  is_default                boolean     NOT NULL DEFAULT false,
  created_at                timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at                timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.packaging_profiles OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.recipes (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brewfather_id   text,
  name            text        NOT NULL,
  style           text,
  abv             double precision,
  ibu             double precision,
  color           double precision,
  data            jsonb,
  image           bytea,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.recipes OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.video_instructions (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  title           text        NOT NULL,
  youtube_url     text        NOT NULL,
  description     text,
  position        integer     DEFAULT 0,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);
ALTER TABLE aibrewgenius.video_instructions OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.water_profiles (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  is_default      boolean     NOT NULL DEFAULT false,
  ph              double precision,
  calcium_ppm     double precision DEFAULT 0,
  magnesium_ppm   double precision DEFAULT 0,
  sodium_ppm      double precision DEFAULT 0,
  chloride_ppm    double precision DEFAULT 0,
  sulfate_ppm     double precision DEFAULT 0,
  bicarbonate_ppm double precision DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at      timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.water_profiles OWNER TO supabase_admin;

CREATE TABLE IF NOT EXISTS aibrewgenius.yeast_bank_entries (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_profile_id    uuid        NOT NULL REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE,
  brewfather_id      text,
  brand              text        NOT NULL,
  strain             text        NOT NULL,
  product_id         text,
  form               text,
  inventory          double precision,
  unit               text,
  style              text,
  attenuation_min    double precision,
  attenuation_max    double precision,
  temperature_min    double precision,
  temperature_max    double precision,
  url                text,
  notes              text,
  zucht_generationen jsonb       DEFAULT '[]'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at         timestamptz NOT NULL DEFAULT timezone('utc', now())
);
ALTER TABLE aibrewgenius.yeast_bank_entries OWNER TO supabase_admin;

-- ---------------------------------------------------------------------------
-- 1d. Unique indexes on child tables
-- ---------------------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS batches_user_brewfather_unique
  ON aibrewgenius.batches (user_profile_id, brewfather_id);
CREATE UNIQUE INDEX IF NOT EXISTS brew_kettles_default_unique
  ON aibrewgenius.brew_kettles (user_profile_id) WHERE is_default;
CREATE UNIQUE INDEX IF NOT EXISTS fermentables_user_brewfather_unique
  ON aibrewgenius.fermentables (user_profile_id, brewfather_id);
CREATE UNIQUE INDEX IF NOT EXISTS fermenter_controllers_default_unique
  ON aibrewgenius.fermenter_controllers (user_profile_id) WHERE is_default;
CREATE UNIQUE INDEX IF NOT EXISTS fermenters_default_unique
  ON aibrewgenius.fermenters (user_profile_id) WHERE is_default;
CREATE UNIQUE INDEX IF NOT EXISTS hops_user_brewfather_unique
  ON aibrewgenius.hops (user_profile_id, brewfather_id);
CREATE UNIQUE INDEX IF NOT EXISTS miscs_user_brewfather_unique
  ON aibrewgenius.miscs (user_profile_id, brewfather_id);
CREATE UNIQUE INDEX IF NOT EXISTS packaging_profiles_default_unique
  ON aibrewgenius.packaging_profiles (user_profile_id) WHERE is_default;
CREATE UNIQUE INDEX IF NOT EXISTS recipes_user_brewfather_unique
  ON aibrewgenius.recipes (user_profile_id, brewfather_id);
CREATE UNIQUE INDEX IF NOT EXISTS water_profiles_default_unique
  ON aibrewgenius.water_profiles (user_profile_id) WHERE is_default;

-- RLS filter indexes on user_profile_id (RLS turns these into per-query predicates)
CREATE INDEX IF NOT EXISTS idx_abg_ai_recipes_v2_upid
  ON aibrewgenius.ai_generated_recipes_v2 (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_batches_upid
  ON aibrewgenius.batches (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_brew_kettles_upid
  ON aibrewgenius.brew_kettles (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_fermentables_upid
  ON aibrewgenius.fermentables (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_fermenter_controllers_upid
  ON aibrewgenius.fermenter_controllers (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_fermenters_upid
  ON aibrewgenius.fermenters (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_hops_upid
  ON aibrewgenius.hops (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_how_to_topics_upid
  ON aibrewgenius.how_to_topics (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_malt_depots_upid
  ON aibrewgenius.malt_depots (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_miscs_upid
  ON aibrewgenius.miscs (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_packaging_profiles_upid
  ON aibrewgenius.packaging_profiles (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_recipes_upid
  ON aibrewgenius.recipes (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_video_instructions_upid
  ON aibrewgenius.video_instructions (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_water_profiles_upid
  ON aibrewgenius.water_profiles (user_profile_id);
CREATE INDEX IF NOT EXISTS idx_abg_yeast_bank_entries_upid
  ON aibrewgenius.yeast_bank_entries (user_profile_id);

-- ---------------------------------------------------------------------------
-- 1e. Updated_at triggers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER batches_set_updated_at
  BEFORE UPDATE ON aibrewgenius.batches
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER brew_kettles_set_updated_at
  BEFORE UPDATE ON aibrewgenius.brew_kettles
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER fermentables_set_updated_at
  BEFORE UPDATE ON aibrewgenius.fermentables
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER fermenter_controllers_set_updated_at
  BEFORE UPDATE ON aibrewgenius.fermenter_controllers
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER fermenters_set_updated_at
  BEFORE UPDATE ON aibrewgenius.fermenters
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER fining_agents_set_updated_at
  BEFORE UPDATE ON aibrewgenius.fining_agents
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER hops_set_updated_at
  BEFORE UPDATE ON aibrewgenius.hops
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER how_to_topics_set_updated_at
  BEFORE UPDATE ON aibrewgenius.how_to_topics
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER malt_depots_set_updated_at
  BEFORE UPDATE ON aibrewgenius.malt_depots
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER miscs_set_updated_at
  BEFORE UPDATE ON aibrewgenius.miscs
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER packaging_profiles_set_updated_at
  BEFORE UPDATE ON aibrewgenius.packaging_profiles
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER recipes_set_updated_at
  BEFORE UPDATE ON aibrewgenius.recipes
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER video_instructions_set_updated_at
  BEFORE UPDATE ON aibrewgenius.video_instructions
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER water_profiles_set_updated_at
  BEFORE UPDATE ON aibrewgenius.water_profiles
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();
CREATE OR REPLACE TRIGGER yeast_bank_entries_set_updated_at
  BEFORE UPDATE ON aibrewgenius.yeast_bank_entries
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.set_updated_at();

-- ---------------------------------------------------------------------------
-- 1f. Enable RLS on all user-facing tables
-- ---------------------------------------------------------------------------
ALTER TABLE aibrewgenius.ai_generated_recipes_v2  ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.batches                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.brew_kettles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.fermentables             ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.fermenter_controllers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.fermenters               ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.fining_agents            ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.hops                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.how_to_topics            ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.keezer_configs           ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.malt_depots              ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.miscs                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.packaging_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.recipes                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.user_profiles            ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.video_instructions       ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.water_profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE aibrewgenius.yeast_bank_entries       ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 1g. RLS Policies (auth.uid()-based, authenticated only)
--     USING (read) and WITH CHECK (write) kept separate.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS user_owns_profile ON aibrewgenius.user_profiles;
CREATE POLICY user_owns_profile ON aibrewgenius.user_profiles
  FOR ALL TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.ai_generated_recipes_v2;
CREATE POLICY user_owns_rows ON aibrewgenius.ai_generated_recipes_v2
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.batches;
CREATE POLICY user_owns_rows ON aibrewgenius.batches
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.brew_kettles;
CREATE POLICY user_owns_rows ON aibrewgenius.brew_kettles
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.fermentables;
CREATE POLICY user_owns_rows ON aibrewgenius.fermentables
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.fermenter_controllers;
CREATE POLICY user_owns_rows ON aibrewgenius.fermenter_controllers
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.fermenters;
CREATE POLICY user_owns_rows ON aibrewgenius.fermenters
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.fining_agents;
CREATE POLICY user_owns_rows ON aibrewgenius.fining_agents
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.hops;
CREATE POLICY user_owns_rows ON aibrewgenius.hops
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.how_to_topics;
CREATE POLICY user_owns_rows ON aibrewgenius.how_to_topics
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.keezer_configs;
CREATE POLICY user_owns_rows ON aibrewgenius.keezer_configs
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.malt_depots;
CREATE POLICY user_owns_rows ON aibrewgenius.malt_depots
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.miscs;
CREATE POLICY user_owns_rows ON aibrewgenius.miscs
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.packaging_profiles;
CREATE POLICY user_owns_rows ON aibrewgenius.packaging_profiles
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.recipes;
CREATE POLICY user_owns_rows ON aibrewgenius.recipes
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.video_instructions;
CREATE POLICY user_owns_rows ON aibrewgenius.video_instructions
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.water_profiles;
CREATE POLICY user_owns_rows ON aibrewgenius.water_profiles
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

DROP POLICY IF EXISTS user_owns_rows ON aibrewgenius.yeast_bank_entries;
CREATE POLICY user_owns_rows ON aibrewgenius.yeast_bank_entries
  FOR ALL TO authenticated
  USING (user_profile_id = auth.uid())
  WITH CHECK (user_profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 1h. Schema + table grants
-- ---------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE
  ON aibrewgenius.ai_generated_recipes_v2,
     aibrewgenius.batches,
     aibrewgenius.brew_kettles,
     aibrewgenius.fermentables,
     aibrewgenius.fermenter_controllers,
     aibrewgenius.fermenters,
     aibrewgenius.fining_agents,
     aibrewgenius.hops,
     aibrewgenius.how_to_topics,
     aibrewgenius.keezer_configs,
     aibrewgenius.malt_depots,
     aibrewgenius.miscs,
     aibrewgenius.packaging_profiles,
     aibrewgenius.recipes,
     aibrewgenius.user_profiles,
     aibrewgenius.video_instructions,
     aibrewgenius.water_profiles,
     aibrewgenius.yeast_bank_entries
  TO authenticated;

GRANT ALL
  ON aibrewgenius.ai_generated_recipes_v2,
     aibrewgenius.batches,
     aibrewgenius.brew_kettles,
     aibrewgenius.fermentables,
     aibrewgenius.fermenter_controllers,
     aibrewgenius.fermenters,
     aibrewgenius.fining_agents,
     aibrewgenius.hops,
     aibrewgenius.how_to_topics,
     aibrewgenius.keezer_configs,
     aibrewgenius.malt_depots,
     aibrewgenius.miscs,
     aibrewgenius.packaging_profiles,
     aibrewgenius.recipes,
     aibrewgenius.user_profiles,
     aibrewgenius.video_instructions,
     aibrewgenius.water_profiles,
     aibrewgenius.yeast_bank_entries
  TO service_role;

-- DEFAULT PRIVILEGES: run without FOR ROLE clause so it executes as supabase_admin
-- (the current role), matching the table ownership. "FOR ROLE postgres" is a no-op
-- because postgres does not own these tables.
ALTER DEFAULT PRIVILEGES IN SCHEMA aibrewgenius
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA aibrewgenius
  GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA aibrewgenius
  GRANT ALL ON SEQUENCES TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1i. Realtime publication (lean stack may not have supabase_realtime pub;
--     guard silently if absent)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  tables_to_add text[] := ARRAY[
    'aibrewgenius.ai_generated_recipes_v2',
    'aibrewgenius.batches',
    'aibrewgenius.recipes',
    'aibrewgenius.fermenter_controllers'
  ];
  t text;
  pub_oid oid;
BEGIN
  SELECT oid INTO pub_oid FROM pg_publication WHERE pubname = 'supabase_realtime';
  IF pub_oid IS NULL THEN
    RETURN; -- lean stack has no realtime service → skip silently
  END IF;

  FOREACH t IN ARRAY tables_to_add LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = split_part(t, '.', 1)
        AND tablename  = split_part(t, '.', 2)
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %s', t);
    END IF;
  END LOOP;
END $$;

-- =============================================================================
-- SECTION 2: SECURITY DEFINER RPCs
-- =============================================================================
-- All with SET search_path = '' and fully-qualified objects.
-- NO rapt RPCs (per-app-DB pivot Entscheidung 2+7).

-- ---------------------------------------------------------------------------
-- 2a. handle_new_user() — trigger on auth.users INSERT
--     Creates user_profiles row automatically for every new user.
--     SECURITY DEFINER: runs as supabase_admin to bypass RLS on insert.
--     SET search_path = '': prevents search-path hijacking.
--     Tenant filter: inserts only NEW.id (the newly created user) — no
--     cross-user write possible.
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

ALTER FUNCTION aibrewgenius.handle_new_user() OWNER TO supabase_admin;
REVOKE EXECUTE ON FUNCTION aibrewgenius.handle_new_user() FROM PUBLIC;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.handle_new_user();

-- ---------------------------------------------------------------------------
-- 2b. get_my_brewfather_creds()
--     SECURITY DEFINER to access vault.decrypted_secrets.
--     Tenant filter: filters on auth.uid() internally — RLS bypassed but
--     filter re-asserted in WHERE clause.
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

ALTER FUNCTION aibrewgenius.get_my_brewfather_creds() OWNER TO supabase_admin;
REVOKE EXECUTE ON FUNCTION aibrewgenius.get_my_brewfather_creds() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION aibrewgenius.get_my_brewfather_creds() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2c. set_my_brewfather_creds(text)
--     SECURITY DEFINER to write vault.secrets and update user_profiles.
--     Tenant filter: all writes scoped to auth.uid() — re-asserted in
--     WHERE clauses even though RLS is bypassed.
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

ALTER FUNCTION aibrewgenius.set_my_brewfather_creds(text) OWNER TO supabase_admin;
REVOKE EXECUTE ON FUNCTION aibrewgenius.set_my_brewfather_creds(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION aibrewgenius.set_my_brewfather_creds(text) TO authenticated;

-- =============================================================================
-- SECTION 3: schema_migrations anchor (baseline = version '000')
-- =============================================================================
INSERT INTO public.schema_migrations (version, applied_at)
VALUES ('000', now())
ON CONFLICT (version) DO NOTHING;

COMMENT ON TABLE public.schema_migrations IS
  'Phase-2 migrations runner tracking. '
  'Version format: 3-digit numeric string (000, 001, 010, ...). '
  'Baseline inserts 000 (ON CONFLICT DO NOTHING = idempotent). '
  'Each subsequent migration inserts its own version at the end of its '
  'transaction. Phase-2 runner: apply files where version > MAX(applied).';

COMMIT;

-- =============================================================================
-- Sanity checks (outside transaction, read-only)
-- =============================================================================
\echo ''
\echo '=== AIBREWGENIUS BASELINE SANITY CHECKS ==='

\echo ''
\echo '== Schema =='
SELECT schema_name FROM information_schema.schemata
WHERE schema_name = 'aibrewgenius';

\echo ''
\echo '== Tables =='
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'aibrewgenius' AND table_type = 'BASE TABLE'
ORDER BY table_name;

\echo ''
\echo '== RLS status =='
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'aibrewgenius'
ORDER BY tablename;

\echo ''
\echo '== Policy count =='
SELECT COUNT(*) AS policy_count FROM pg_policies WHERE schemaname = 'aibrewgenius';

\echo ''
\echo '== SECURITY DEFINER functions (search_path must be empty) =='
SELECT p.proname AS function, p.prosecdef, p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'aibrewgenius' AND p.prosecdef = true
ORDER BY p.proname;

\echo ''
\echo '== Trigger on auth.users =='
SELECT tgname FROM pg_trigger
WHERE tgrelid = 'auth.users'::regclass AND tgname = 'on_auth_user_created';

\echo ''
\echo '== RAPT shims (must be EMPTY) =='
SELECT proname FROM pg_proc
WHERE pronamespace = 'aibrewgenius'::regnamespace
  AND proname IN ('get_my_rapt_creds', 'set_my_rapt_creds');

\echo ''
\echo '== user_profiles columns (no rapt_* columns) =='
SELECT column_name, data_type, is_generated
FROM information_schema.columns
WHERE table_schema = 'aibrewgenius' AND table_name = 'user_profiles'
ORDER BY ordinal_position;

\echo ''
\echo '== schema_migrations =='
SELECT version, applied_at FROM public.schema_migrations ORDER BY version;

\echo ''
\echo '=== DONE ==='
