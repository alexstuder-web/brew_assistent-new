-- =============================================================================
-- 001_init_schema.sql — HISTORISCHER BASELINE-STAND
-- =============================================================================
-- Diese Datei ist der ursprüngliche Schema-Dump (Single-User, pre-Auth, pre-Vault).
-- Sie wird NUR für ein komplettes Greenfield-Setup (leere DB) verwendet.
-- Für jedes andere Setup — Migration einer bestehenden Instanz, lokale Entwicklung
-- oder Produktion — MÜSSEN danach zwingend alle Migrationen in aufsteigender
-- Reihenfolge angewendet werden:
--
--   002_auth.sql                       Multi-User + RLS (user_profiles.id → uuid,
--                                      alle Child-FKs, RLS-Policies, Auth-Trigger)
--   003_vault.sql                      API-Keys encrypted-at-rest via vault.secrets;
--                                      Klartext-Spalten brewfather_api_key /
--                                      rapt_api_key werden genullt.
--   004_proxy_role.sql                 Dedizierter proxy_sync-Role für den BFF.
--   005_fix_proxy_role_grants.sql      Grant-Korrekturen für proxy_sync.
--   006_retire_aibrewgenius_rapt.sql   RAPT-Creds in rapt-Schema delegiert;
--                                      aibrewgenius-RAPT-RPCs zu Shims degradiert.
--   007_harden_brewfather_search_path.sql  search_path-Härtung für Brewfather-RPCs.
--   008_drop_aibrewgenius_rapt_columns.sql Physischer Drop der RAPT-Spalten
--                                      (rapt_configured, rapt_secret_id,
--                                       rapt_user_id, rapt_api_key) aus
--                                      aibrewgenius.user_profiles.
--   009_drop_aibrewgenius_rapt_shims.sql   Drop der RAPT-Delegation-RPCs
--                                      (get_my_rapt_creds / set_my_rapt_creds)
--                                      aus dem aibrewgenius-Schema.
--
-- Spalten, die in diesem Baseline sichtbar sind, aber per Migration entfernt
-- oder verschoben wurden:
--   user_profiles.rapt_user_id / rapt_api_key  → dropped by 008
--   user_profiles.brewfather_api_key           → zeroed (vault) by 003,
--                                                nicht gedroppt (Klartext-Spalte bleibt)
-- =============================================================================

DROP SCHEMA IF EXISTS aibrewgenius CASCADE;



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


CREATE SCHEMA IF NOT EXISTS "aibrewgenius";


ALTER SCHEMA "aibrewgenius" OWNER TO "supabase_admin";


CREATE OR REPLACE FUNCTION "aibrewgenius"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = TIMEZONE('utc', NOW());
  RETURN NEW;
END;
$$;


ALTER FUNCTION "aibrewgenius"."set_updated_at"() OWNER TO "supabase_admin";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."ai_generated_recipes_v2" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "basis_bier" "text",
    "bier_typ" "text",
    "stammwuerze_sg" double precision,
    "restextrakt_sg" double precision,
    "alkoholgehalt" double precision,
    "notizen" "text"[],
    "generated_image" "text",
    "yeast_name" "text",
    "yeast_type" "text",
    "yeast_amount" "text",
    "yeast_procurement_needed" boolean,
    "water_ca" integer,
    "water_mg" integer,
    "water_na" integer,
    "water_cl" integer,
    "water_so4" integer,
    "water_hco3" integer,
    "water_salt_timing" "text",
    "mash_water_l" double precision,
    "mash_in_temp_c" double precision,
    "lauter_sparge_water_l" double precision,
    "lauter_target_ph" "text",
    "boil_pre_vol_l" double precision,
    "boil_duration_min" integer,
    "fermentation_pitch_temp_c" double precision,
    "packaging_type" "text",
    "packaging_co2_target" double precision,
    "packaging_keg_pressure" double precision,
    "packaging_keg_temp" double precision,
    "packaging_bottle_sugar" double precision,
    "packaging_bottle_temp" double precision,
    "packaging_storage_temp" double precision,
    "packaging_storage_weeks" integer,
    "packaging_maturation_note" "text",
    "packaging_serving_gas" "text",
    "packaging_carb_days" integer,
    "can_pressurize" boolean DEFAULT false,
    "fermentation_pressure_note" "text",
    "bjcp_stil" "jsonb",
    "ibu" double precision,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "malts" "jsonb" DEFAULT '[]'::"jsonb",
    "hops" "jsonb" DEFAULT '[]'::"jsonb",
    "specials" "jsonb" DEFAULT '[]'::"jsonb",
    "finings" "jsonb" DEFAULT '[]'::"jsonb",
    "mash_steps" "jsonb" DEFAULT '[]'::"jsonb",
    "fermentation_steps" "jsonb" DEFAULT '[]'::"jsonb"
);


ALTER TABLE "aibrewgenius"."ai_generated_recipes_v2" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."batches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brewfather_id" "text",
    "name" "text" NOT NULL,
    "batch_no" integer,
    "status" "text",
    "brew_date" bigint,
    "recipe_name" "text",
    "analysis_data" "jsonb",
    "rapt_data" "jsonb",
    "data" "jsonb",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."batches" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."brew_kettles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brand" "text" NOT NULL,
    "model" "text",
    "is_default" boolean DEFAULT false NOT NULL,
    "volume_liters" double precision,
    "post_boil_loss_liters" double precision DEFAULT 0,
    "boil_off_percentage" double precision DEFAULT 0,
    "bh_efficiency" double precision DEFAULT 70,
    "has_condenser_hat" boolean DEFAULT false NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."brew_kettles" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."fermentables" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brewfather_id" "text",
    "name" "text" NOT NULL,
    "supplier" "text",
    "amount" double precision,
    "unit" "text",
    "type" "text",
    "potential" double precision,
    "yield" double precision,
    "attenuation" double precision,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."fermentables" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."fermenter_controllers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "username" "text",
    "api_key" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."fermenter_controllers" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."fermenters" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brand" "text" NOT NULL,
    "type" "text",
    "is_default" boolean DEFAULT false NOT NULL,
    "volume_liters" double precision,
    "has_heating" boolean DEFAULT false NOT NULL,
    "has_cooling" boolean DEFAULT false NOT NULL,
    "has_dry_hopping_port" boolean DEFAULT false NOT NULL,
    "can_pressurize" boolean DEFAULT false NOT NULL,
    "fermentation_loss_liters" double precision DEFAULT 0 NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."fermenters" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."fining_agents" (
    "user_profile_id" "text" NOT NULL,
    "irish_moss" boolean DEFAULT false NOT NULL,
    "whirlfloc" boolean DEFAULT false NOT NULL,
    "gelatin" boolean DEFAULT false NOT NULL,
    "biersol" boolean DEFAULT false NOT NULL,
    "polyclar" boolean DEFAULT false NOT NULL,
    "isinglass" boolean DEFAULT false NOT NULL,
    "bentonite" boolean DEFAULT false NOT NULL,
    "egg_whites" boolean DEFAULT false NOT NULL,
    "activated_carbon" boolean DEFAULT false NOT NULL,
    "extras" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."fining_agents" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."hops" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brewfather_id" "text",
    "name" "text" NOT NULL,
    "alpha" double precision,
    "origin" "text",
    "year" "text",
    "amount" double precision,
    "unit" "text",
    "type" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."hops" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."malt_depots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "url" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."malt_depots" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."miscs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brewfather_id" "text",
    "name" "text" NOT NULL,
    "amount" double precision,
    "unit" "text",
    "type" "text",
    "use" "text",
    "time" double precision,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."miscs" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."packaging_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "target_volume" double precision,
    "bottle_enabled" boolean DEFAULT false NOT NULL,
    "bottle_carbonation_temp_c" double precision,
    "bottle_storage_temp_c" double precision,
    "keg_enabled" boolean DEFAULT false NOT NULL,
    "keg_carbonation_temp_c" double precision,
    "keg_storage_temp_c" double precision,
    "keg_volume_l" double precision,
    "has_co2" boolean DEFAULT true NOT NULL,
    "has_nitro" boolean DEFAULT false NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."packaging_profiles" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."recipes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brewfather_id" "text",
    "name" "text" NOT NULL,
    "style" "text",
    "abv" double precision,
    "ibu" double precision,
    "color" double precision,
    "data" "jsonb",
    "image" "bytea",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."recipes" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."user_profiles" (
    "id" "text" NOT NULL,
    "name" "text",
    "avatar_blob" "text",
    "default_batch_liters" double precision,
    "rapt_user_id" "text",
    "rapt_api_key" "text",
    "brewfather_user_id" "text",
    "brewfather_api_key" "text",
    "brewfather_sync_enabled" boolean DEFAULT false NOT NULL,
    "language" "text"
);


ALTER TABLE "aibrewgenius"."user_profiles" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."water_profiles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "name" "text" NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "ph" double precision,
    "calcium_ppm" double precision DEFAULT 0,
    "magnesium_ppm" double precision DEFAULT 0,
    "sodium_ppm" double precision DEFAULT 0,
    "chloride_ppm" double precision DEFAULT 0,
    "sulfate_ppm" double precision DEFAULT 0,
    "bicarbonate_ppm" double precision DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."water_profiles" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."yeast_bank_entries" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "brewfather_id" "text",
    "brand" "text" NOT NULL,
    "strain" "text" NOT NULL,
    "product_id" "text",
    "form" "text",
    "inventory" double precision,
    "unit" "text",
    "style" "text",
    "attenuation_min" double precision,
    "attenuation_max" double precision,
    "temperature_min" double precision,
    "temperature_max" double precision,
    "url" "text",
    "notes" "text",
    "zucht_generationen" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."yeast_bank_entries" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."keezer_configs" (
    "user_profile_id" "text" NOT NULL,
    "num_taps" integer DEFAULT 0,
    "taps" "jsonb" DEFAULT '[]'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "aibrewgenius"."keezer_configs" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."how_to_topics" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text" DEFAULT '',
    "pages" "jsonb" DEFAULT '[]'::"jsonb",
    "position" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);

ALTER TABLE "aibrewgenius"."how_to_topics" OWNER TO "supabase_admin";


CREATE TABLE IF NOT EXISTS "aibrewgenius"."video_instructions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_profile_id" "text" NOT NULL,
    "title" "text" NOT NULL,
    "youtube_url" "text" NOT NULL,
    "description" "text",
    "position" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE "aibrewgenius"."video_instructions" OWNER TO "supabase_admin";



ALTER TABLE ONLY "aibrewgenius"."ai_generated_recipes_v2"
    ADD CONSTRAINT "ai_generated_recipes_v2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."batches"
    ADD CONSTRAINT "batches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."brew_kettles"
    ADD CONSTRAINT "brew_kettles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."fermentables"
    ADD CONSTRAINT "fermentables_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."fermenter_controllers"
    ADD CONSTRAINT "fermenter_controllers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."fermenters"
    ADD CONSTRAINT "fermenters_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."fining_agents"
    ADD CONSTRAINT "fining_agents_pkey" PRIMARY KEY ("user_profile_id");



ALTER TABLE ONLY "aibrewgenius"."hops"
    ADD CONSTRAINT "hops_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."malt_depots"
    ADD CONSTRAINT "malt_depots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."miscs"
    ADD CONSTRAINT "miscs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."packaging_profiles"
    ADD CONSTRAINT "packaging_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."recipes"
    ADD CONSTRAINT "recipes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."user_profiles"
    ADD CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."water_profiles"
    ADD CONSTRAINT "water_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "aibrewgenius"."yeast_bank_entries"
    ADD CONSTRAINT "yeast_bank_entries_pkey" PRIMARY KEY ("id");
    
ALTER TABLE ONLY "aibrewgenius"."keezer_configs"
    ADD CONSTRAINT "keezer_configs_pkey" PRIMARY KEY ("user_profile_id");

ALTER TABLE ONLY "aibrewgenius"."how_to_topics"
    ADD CONSTRAINT "how_to_topics_pkey" PRIMARY KEY ("id");

ALTER TABLE ONLY "aibrewgenius"."video_instructions"
    ADD CONSTRAINT "video_instructions_pkey" PRIMARY KEY ("id");




CREATE UNIQUE INDEX "batches_user_brewfather_unique" ON "aibrewgenius"."batches" USING "btree" ("user_profile_id", "brewfather_id");



CREATE UNIQUE INDEX "brew_kettles_default_unique" ON "aibrewgenius"."brew_kettles" USING "btree" ("user_profile_id") WHERE "is_default";



CREATE UNIQUE INDEX "fermentables_user_brewfather_unique" ON "aibrewgenius"."fermentables" USING "btree" ("user_profile_id", "brewfather_id");



CREATE UNIQUE INDEX "fermenter_controllers_default_unique" ON "aibrewgenius"."fermenter_controllers" USING "btree" ("user_profile_id") WHERE "is_default";



CREATE UNIQUE INDEX "fermenters_default_unique" ON "aibrewgenius"."fermenters" USING "btree" ("user_profile_id") WHERE "is_default";



CREATE UNIQUE INDEX "hops_user_brewfather_unique" ON "aibrewgenius"."hops" USING "btree" ("user_profile_id", "brewfather_id");



CREATE UNIQUE INDEX "miscs_user_brewfather_unique" ON "aibrewgenius"."miscs" USING "btree" ("user_profile_id", "brewfather_id");



CREATE UNIQUE INDEX "packaging_profiles_default_unique" ON "aibrewgenius"."packaging_profiles" USING "btree" ("user_profile_id") WHERE "is_default";



CREATE UNIQUE INDEX "recipes_user_brewfather_unique" ON "aibrewgenius"."recipes" USING "btree" ("user_profile_id", "brewfather_id");



CREATE UNIQUE INDEX "water_profiles_default_unique" ON "aibrewgenius"."water_profiles" USING "btree" ("user_profile_id") WHERE "is_default";



CREATE OR REPLACE TRIGGER "batches_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."batches" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "brew_kettles_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."brew_kettles" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "fermentables_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."fermentables" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "fermenter_controllers_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."fermenter_controllers" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "fermenters_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."fermenters" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "fining_agents_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."fining_agents" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "hops_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."hops" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "malt_depots_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."malt_depots" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "miscs_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."miscs" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "packaging_profiles_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."packaging_profiles" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "recipes_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."recipes" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "water_profiles_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."water_profiles" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();



CREATE OR REPLACE TRIGGER "yeast_bank_entries_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."yeast_bank_entries" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();
    
CREATE OR REPLACE TRIGGER "how_to_topics_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."how_to_topics" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();
    
CREATE OR REPLACE TRIGGER "video_instructions_set_updated_at" BEFORE UPDATE ON "aibrewgenius"."video_instructions" FOR EACH ROW EXECUTE FUNCTION "aibrewgenius"."set_updated_at"();




ALTER TABLE ONLY "aibrewgenius"."batches"
    ADD CONSTRAINT "batches_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."brew_kettles"
    ADD CONSTRAINT "brew_kettles_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."fermentables"
    ADD CONSTRAINT "fermentables_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."fermenter_controllers"
    ADD CONSTRAINT "fermenter_controllers_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."fermenters"
    ADD CONSTRAINT "fermenters_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."fining_agents"
    ADD CONSTRAINT "fining_agents_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."hops"
    ADD CONSTRAINT "hops_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."malt_depots"
    ADD CONSTRAINT "malt_depots_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."miscs"
    ADD CONSTRAINT "miscs_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."packaging_profiles"
    ADD CONSTRAINT "packaging_profiles_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."recipes"
    ADD CONSTRAINT "recipes_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."water_profiles"
    ADD CONSTRAINT "water_profiles_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "aibrewgenius"."yeast_bank_entries"
    ADD CONSTRAINT "yeast_bank_entries_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "aibrewgenius"."keezer_configs"
    ADD CONSTRAINT "keezer_configs_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "aibrewgenius"."how_to_topics"
    ADD CONSTRAINT "how_to_topics_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;

ALTER TABLE ONLY "aibrewgenius"."video_instructions"
    ADD CONSTRAINT "video_instructions_user_profile_id_fkey" FOREIGN KEY ("user_profile_id") REFERENCES "aibrewgenius"."user_profiles"("id") ON DELETE CASCADE;




CREATE POLICY "Allow full access" ON "aibrewgenius"."batches" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."brew_kettles" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."fermentables" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."fermenter_controllers" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."fermenters" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."fining_agents" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."hops" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."malt_depots" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."miscs" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."packaging_profiles" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."recipes" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."user_profiles" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."water_profiles" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow full access" ON "aibrewgenius"."yeast_bank_entries" TO "anon" USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access" ON "aibrewgenius"."keezer_configs" TO "anon" USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access" ON "aibrewgenius"."how_to_topics" TO "anon" USING (true) WITH CHECK (true);

CREATE POLICY "Allow full access" ON "aibrewgenius"."video_instructions" TO "anon" USING (true) WITH CHECK (true);




CREATE POLICY "Allow full access recipes v2" ON "aibrewgenius"."ai_generated_recipes_v2" TO "anon" USING (true) WITH CHECK (true);



ALTER TABLE "aibrewgenius"."ai_generated_recipes_v2" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."batches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."brew_kettles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."fermentables" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."fermenter_controllers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."fermenters" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."fining_agents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."hops" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."malt_depots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."miscs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."packaging_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."recipes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."user_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."water_profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "aibrewgenius"."yeast_bank_entries" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "aibrewgenius"."keezer_configs" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "aibrewgenius"."how_to_topics" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "aibrewgenius"."video_instructions" ENABLE ROW LEVEL SECURITY;



GRANT ALL ON SCHEMA "aibrewgenius" TO "anon";
GRANT ALL ON SCHEMA "aibrewgenius" TO "authenticated";
GRANT ALL ON SCHEMA "aibrewgenius" TO "service_role";
GRANT ALL ON SCHEMA "aibrewgenius" TO "postgres";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."ai_generated_recipes_v2" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."ai_generated_recipes_v2" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."ai_generated_recipes_v2" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."batches" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."batches" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."batches" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."brew_kettles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."brew_kettles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."brew_kettles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermentables" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermentables" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermentables" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermenter_controllers" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermenter_controllers" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermenter_controllers" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermenters" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermenters" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fermenters" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fining_agents" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fining_agents" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."fining_agents" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."hops" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."hops" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."hops" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."malt_depots" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."malt_depots" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."malt_depots" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."miscs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."miscs" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."miscs" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."packaging_profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."packaging_profiles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."packaging_profiles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."recipes" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."recipes" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."recipes" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."user_profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."user_profiles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."user_profiles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."water_profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."water_profiles" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."water_profiles" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."yeast_bank_entries" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."yeast_bank_entries" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."yeast_bank_entries" TO "service_role";

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."keezer_configs" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."keezer_configs" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."keezer_configs" TO "service_role";

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."how_to_topics" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."how_to_topics" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."how_to_topics" TO "service_role";

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."video_instructions" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."video_instructions" TO "authenticated";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE "aibrewgenius"."video_instructions" TO "service_role";







ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "aibrewgenius" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "aibrewgenius" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "aibrewgenius" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "aibrewgenius" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "aibrewgenius" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "aibrewgenius" GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO "service_role";





-- Enable Realtime for ai_generated_recipes_v2
ALTER PUBLICATION supabase_realtime ADD TABLE aibrewgenius.ai_generated_recipes_v2;
ALTER PUBLICATION supabase_realtime ADD TABLE aibrewgenius.batches;
ALTER PUBLICATION supabase_realtime ADD TABLE aibrewgenius.recipes;
ALTER PUBLICATION supabase_realtime ADD TABLE aibrewgenius.fermenter_controllers;
