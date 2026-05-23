-- =============================================================================
-- Migration 002: self_hosted_profile -> auth.uid()
-- =============================================================================
-- Stellt das aibrewgenius-Schema von single-user (text id 'self_hosted_profile')
-- auf multi-user mit Supabase Auth (uuid, FK -> auth.users.id) um.
--
-- Schritte:
--   1. Bootstrap-Auth-User anlegen (alex@alexstuder.ch, Test-Passwort)
--   2. Bestehende RLS-Policies droppen
--   3. FK-Constraints droppen (16x)
--   4. Spalten-Typen migrieren: user_profile_id text -> uuid
--   5. user_profiles.id text -> uuid (mit der Bootstrap-UUID)
--   6. FK user_profiles.id -> auth.users.id hinzufügen
--   7. Child-FKs wiederherstellen
--   8. Neue RLS-Policies mit auth.uid()
--   9. Trigger: neue auth.users -> automatisch user_profiles-Row erzeugen
--
-- Alles in einer Transaktion. Rollback bei Fehler.
-- =============================================================================

BEGIN;

DO $migration$
DECLARE
  v_user_id         uuid;
  v_user_email      text := 'alex@alexstuder.ch';
  v_user_password   text := 'asdf';
  v_old_profile_id  text := 'self_hosted_profile';
  v_tbl             text;
  v_child_tables    text[] := ARRAY[
    'ai_generated_recipes_v2',
    'batches',
    'brew_kettles',
    'fermentables',
    'fermenter_controllers',
    'fermenters',
    'fining_agents',
    'hops',
    'how_to_topics',
    'keezer_configs',
    'malt_depots',
    'miscs',
    'packaging_profiles',
    'recipes',
    'video_instructions',
    'water_profiles',
    'yeast_bank_entries'
  ];
  v_fk_tables       text[] := ARRAY[
    'batches',
    'brew_kettles',
    'fermentables',
    'fermenter_controllers',
    'fermenters',
    'fining_agents',
    'hops',
    'how_to_topics',
    'keezer_configs',
    'malt_depots',
    'miscs',
    'packaging_profiles',
    'recipes',
    'video_instructions',
    'water_profiles',
    'yeast_bank_entries'
  ];
BEGIN
  -- ---------------------------------------------------------------------------
  -- Schritt 1: Auth-User anlegen
  -- ---------------------------------------------------------------------------
  -- Prüfen, ob es bereits einen User mit dieser Email gibt (idempotent)
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_user_email;

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();

    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000',
      v_user_id,
      'authenticated',
      'authenticated',
      v_user_email,
      crypt(v_user_password, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{}'::jsonb,
      now(),
      now(),
      '', '', '', ''
    );

    -- auth.identities Row (von GoTrue für Login mit Passwort gebraucht)
    INSERT INTO auth.identities (
      provider_id,
      user_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) VALUES (
      v_user_id::text,
      v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', v_user_email),
      'email',
      now(),
      now(),
      now()
    );

    RAISE NOTICE 'Auth user angelegt: % (id=%)', v_user_email, v_user_id;
  ELSE
    RAISE NOTICE 'Auth user existiert bereits: % (id=%)', v_user_email, v_user_id;
  END IF;

  -- ---------------------------------------------------------------------------
  -- Schritt 2: Alte RLS-Policies droppen
  -- ---------------------------------------------------------------------------
  FOR v_tbl IN
    SELECT tablename FROM pg_policies WHERE schemaname = 'aibrewgenius'
  LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON aibrewgenius.%I',
      (SELECT policyname FROM pg_policies WHERE schemaname = 'aibrewgenius' AND tablename = v_tbl LIMIT 1),
      v_tbl
    );
  END LOOP;

  -- Defensiv noch beide bekannten Policy-Namen droppen
  FOREACH v_tbl IN ARRAY v_child_tables LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Allow full access" ON aibrewgenius.%I', v_tbl);
    EXECUTE format('DROP POLICY IF EXISTS "Allow full access recipes v2" ON aibrewgenius.%I', v_tbl);
  END LOOP;
  EXECUTE 'DROP POLICY IF EXISTS "Allow full access" ON aibrewgenius.user_profiles';

  -- ---------------------------------------------------------------------------
  -- Schritt 3: FK-Constraints droppen
  -- ---------------------------------------------------------------------------
  FOREACH v_tbl IN ARRAY v_fk_tables LOOP
    EXECUTE format(
      'ALTER TABLE aibrewgenius.%I DROP CONSTRAINT IF EXISTS %I',
      v_tbl,
      v_tbl || '_user_profile_id_fkey'
    );
  END LOOP;

  -- ---------------------------------------------------------------------------
  -- Schritt 4: user_profile_id text -> uuid (in allen Child-Tabellen)
  -- ---------------------------------------------------------------------------
  FOREACH v_tbl IN ARRAY v_child_tables LOOP
    EXECUTE format(
      'ALTER TABLE aibrewgenius.%I ALTER COLUMN user_profile_id TYPE uuid USING %L::uuid',
      v_tbl,
      v_user_id
    );
  END LOOP;

  -- ---------------------------------------------------------------------------
  -- Schritt 5: user_profiles.id text -> uuid
  -- ---------------------------------------------------------------------------
  EXECUTE format(
    'ALTER TABLE aibrewgenius.user_profiles ALTER COLUMN id TYPE uuid USING %L::uuid',
    v_user_id
  );

  -- ---------------------------------------------------------------------------
  -- Schritt 6: user_profiles.id -> auth.users.id (neue FK)
  -- ---------------------------------------------------------------------------
  ALTER TABLE aibrewgenius.user_profiles
    ADD CONSTRAINT user_profiles_id_fkey
    FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

  -- ---------------------------------------------------------------------------
  -- Schritt 7: Child-FKs wiederherstellen
  -- ---------------------------------------------------------------------------
  FOREACH v_tbl IN ARRAY v_fk_tables LOOP
    EXECUTE format(
      'ALTER TABLE aibrewgenius.%I
         ADD CONSTRAINT %I
         FOREIGN KEY (user_profile_id)
         REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE',
      v_tbl,
      v_tbl || '_user_profile_id_fkey'
    );
  END LOOP;

  -- ai_generated_recipes_v2 hatte vorher keine FK — jetzt setzen wir eine
  ALTER TABLE aibrewgenius.ai_generated_recipes_v2
    ADD CONSTRAINT ai_generated_recipes_v2_user_profile_id_fkey
    FOREIGN KEY (user_profile_id) REFERENCES aibrewgenius.user_profiles(id) ON DELETE CASCADE;

  -- ---------------------------------------------------------------------------
  -- Schritt 8: Neue RLS-Policies (auth.uid()-basiert)
  -- ---------------------------------------------------------------------------
  -- user_profiles: id = auth.uid()
  EXECUTE 'CREATE POLICY user_owns_profile ON aibrewgenius.user_profiles
             FOR ALL TO authenticated
             USING (id = auth.uid())
             WITH CHECK (id = auth.uid())';

  -- Alle Child-Tabellen: user_profile_id = auth.uid()
  FOREACH v_tbl IN ARRAY v_child_tables LOOP
    EXECUTE format(
      'CREATE POLICY user_owns_rows ON aibrewgenius.%I
         FOR ALL TO authenticated
         USING (user_profile_id = auth.uid())
         WITH CHECK (user_profile_id = auth.uid())',
      v_tbl
    );
  END LOOP;

  -- anon darf nichts mehr im Schema (außer was wir explizit erlauben)
  -- RLS bleibt enabled; ohne Policy für anon = kein Zugriff

  RAISE NOTICE 'Migration abgeschlossen. User: % (id=%)', v_user_email, v_user_id;
END
$migration$;

-- =============================================================================
-- Trigger: Neuer Auth-User -> automatisch user_profiles-Row
-- =============================================================================
-- Damit Multi-User-Signups (später) sofort eine Profil-Row haben.
CREATE OR REPLACE FUNCTION aibrewgenius.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = aibrewgenius, public
AS $$
BEGIN
  INSERT INTO aibrewgenius.user_profiles (id, name, language, brewfather_sync_enabled)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    'de',
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION aibrewgenius.handle_new_user();

COMMIT;

-- =============================================================================
-- Post-Migration Sanity Checks (nicht-destruktiv, lesen nur)
-- =============================================================================
\echo ''
\echo '== Sanity Checks =='
SELECT 'auth_users' AS check, count(*) AS value FROM auth.users
UNION ALL SELECT 'user_profiles', count(*) FROM aibrewgenius.user_profiles
UNION ALL SELECT 'batches', count(*) FROM aibrewgenius.batches
UNION ALL SELECT 'recipes', count(*) FROM aibrewgenius.recipes
UNION ALL SELECT 'water_profiles', count(*) FROM aibrewgenius.water_profiles
UNION ALL SELECT 'fermenters', count(*) FROM aibrewgenius.fermenters
UNION ALL SELECT 'policies_total', count(*) FROM pg_policies WHERE schemaname = 'aibrewgenius'
;

\echo ''
\echo '== Auth User =='
SELECT id, email FROM auth.users WHERE email = 'alex@alexstuder.ch';

\echo ''
\echo '== User Profile (sollte die gleiche id haben) =='
SELECT id, name FROM aibrewgenius.user_profiles;
