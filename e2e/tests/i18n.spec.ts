/**
 * Suite 12: i18n Sprach-Toggle
 *
 * Scope: Locale-Switch on UserProfilePage; persistence of language preference
 *        across logout/login.
 *
 * Tests:
 *   1. UserProfilePage in de: "Wasserprofile" button is visible.
 *      Switch language to en via dropdown → save → "Water profiles" button visible
 *      without a full page reload.
 *   2. language preference in user_profiles.language persists over logout/login:
 *      set language = "en" via API → reload app from scratch (new context) →
 *      "Water profiles" label is visible (locale restored from DB on boot).
 *
 * Safety:
 *   - Original name + language are snapshot before the suite in beforeAll.
 *   - Both are restored in afterAll regardless of test outcomes.
 *   - Vault is NOT touched by this suite.
 *
 * Known app behaviour (confirmed in profile.spec.ts):
 *   Saving language via the profile form rebuilds the Flutter MaterialApp locale
 *   immediately — labels change on the same page view without a full reload.
 *   This is relied upon in test 1.
 */

import { test, expect, request as playwrightRequest, APIRequestContext } from '@playwright/test';
import { waitForFlutter } from '../fixtures/flutter-a11y';
import { apiLogin, STORAGE_STATE } from '../fixtures/auth';

test.describe('i18n Sprach-Toggle', () => {
  test.describe.configure({ mode: 'serial' });

  const BASE_URL = process.env.BASE_URL ?? 'http://localhost:8081';
  const SUPABASE_URL = process.env.SUPABASE_URL ?? 'http://localhost:54321';
  const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? '';

  // ---------------------------------------------------------------------------
  // Shared state
  // ---------------------------------------------------------------------------
  let apiCtx: APIRequestContext;
  let token: string;
  let uid: string;
  let originalName: string | null = null;
  let originalLanguage: string | null = null;

  // ---------------------------------------------------------------------------
  // JWT sub-claim extractor (no verify — this is test code only)
  // ---------------------------------------------------------------------------
  function jwtSub(t: string): string {
    const payload = t.split('.')[1];
    const decoded = Buffer.from(payload, 'base64url').toString('utf8');
    return (JSON.parse(decoded) as { sub: string }).sub;
  }

  // ---------------------------------------------------------------------------
  // REST helpers
  // ---------------------------------------------------------------------------
  async function fetchProfile(): Promise<{ name: string; language: string } | null> {
    const res = await apiCtx.get(
      `${SUPABASE_URL}/rest/v1/user_profiles?id=eq.${uid}&select=name,language`,
      {
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${token}`,
          'Accept-Profile': 'aibrewgenius',
          Accept: 'application/json',
        },
      },
    );
    if (!res.ok()) return null;
    const rows = (await res.json()) as Array<{ name: string; language: string }>;
    return rows.length > 0 ? rows[0] : null;
  }

  async function patchLanguage(lang: string): Promise<void> {
    const res = await apiCtx.patch(
      `${SUPABASE_URL}/rest/v1/user_profiles?id=eq.${uid}`,
      {
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${token}`,
          'Content-Profile': 'aibrewgenius',
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        data: { language: lang },
      },
    );
    if (!res.ok()) {
      const body = await res.text();
      throw new Error(`patchLanguage(${lang}) failed (${res.status()}): ${body}`);
    }
  }

  // ---------------------------------------------------------------------------
  // UI navigation
  // ---------------------------------------------------------------------------
  async function openUserProfilePage(page: import('@playwright/test').Page): Promise<void> {
    await page.goto(BASE_URL);
    await waitForFlutter(page);
    await expect(
      page.getByRole('button', { name: /Users profil/i }),
    ).toBeVisible({ timeout: 15_000 });
    await page.getByRole('button', { name: /Users profil/i }).click();
    await waitForFlutter(page);
    await expect(
      page.getByRole('button', { name: /Profil speichern|Save Profile/i }),
    ).toBeVisible({ timeout: 15_000 });
  }

  // ---------------------------------------------------------------------------
  // beforeAll: snapshot profile; ensure de locale for clean test start
  // ---------------------------------------------------------------------------
  test.beforeAll(async () => {
    apiCtx = await playwrightRequest.newContext();
    token = await apiLogin(apiCtx);
    uid = jwtSub(token);

    const profile = await fetchProfile();
    if (profile) {
      originalName = profile.name;
      originalLanguage = profile.language;
      console.log(`[i18n] Snapshot: name="${originalName}", language="${originalLanguage}"`);
    } else {
      console.warn('[i18n] Could not fetch profile snapshot — restore will be skipped');
    }

    // Ensure we start in German so tests are deterministic
    if (profile?.language !== 'de') {
      await patchLanguage('de');
      console.log('[i18n] Set language to "de" for test run baseline');
    }
  });

  // ---------------------------------------------------------------------------
  // afterAll: restore original profile (name + language)
  // ---------------------------------------------------------------------------
  test.afterAll(async () => {
    if (originalLanguage !== null || originalName !== null) {
      console.log(`[i18n] Restoring: name="${originalName}", language="${originalLanguage}"`);
      const patchData: Record<string, string> = {};
      if (originalName !== null) patchData.name = originalName;
      if (originalLanguage !== null) patchData.language = originalLanguage;

      const res = await apiCtx.patch(
        `${SUPABASE_URL}/rest/v1/user_profiles?id=eq.${uid}`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token}`,
            'Content-Profile': 'aibrewgenius',
            'Content-Type': 'application/json',
            Prefer: 'return=minimal',
          },
          data: patchData,
        },
      );
      if (!res.ok()) {
        const body = await res.text();
        throw new Error(`[i18n] Profile restore FAILED (${res.status()}): ${body}`);
      }
      console.log('[i18n] Profile restored.');
    }
    await apiCtx.dispose();
  });

  // ==========================================================================
  // Test 1: Locale switch de → en updates UI labels without full reload
  // ==========================================================================
  test(
    'UserProfilePage in de shows "Wasserprofile"; switch to en → "Water profiles" visible',
    async ({ browser }) => {
      // Ensure de baseline (beforeAll may have set it, but be explicit)
      await patchLanguage('de');

      const ctx = await browser.newContext({ storageState: STORAGE_STATE });
      const page = await ctx.newPage();
      try {
        await openUserProfilePage(page);

        // ---- Assert German label ----
        await expect(
          page.getByRole('button', { name: /Wasserprofile/i }),
        ).toBeVisible({ timeout: 10_000 });

        // ---- Switch to English ----
        const sprachBtn = page.getByRole('button', { name: /Sprache/i });
        await expect(sprachBtn).toBeVisible({ timeout: 5_000 });
        await sprachBtn.click();
        await waitForFlutter(page);

        // Dropdown option — match whatever Flutter renders (option / menuitem / text)
        const englishOption = page
          .getByRole('option', { name: /English/i })
          .or(page.getByRole('menuitem', { name: /English/i }))
          .or(page.getByText('English').first());
        await expect(englishOption).toBeVisible({ timeout: 5_000 });
        await englishOption.click();
        await waitForFlutter(page);

        // Language button label should now reflect English
        await expect(
          page.getByRole('button', { name: /Sprache.*English|English/i }),
        ).toBeVisible({ timeout: 5_000 });

        // Save
        await page.getByRole('button', { name: /Profil speichern|Save Profile/i }).click();
        await page.waitForTimeout(2_000);

        // ---- Assert English label appeared ----
        // The locale rebuilds MaterialApp on save (confirmed in profile.spec.ts).
        // "Water profiles" (en) should now appear where "Wasserprofile" (de) was.
        await expect(
          page.getByRole('button', { name: /Water profiles/i }),
        ).toBeVisible({ timeout: 8_000 });

        // ---- Verify DB updated ----
        const profile = await fetchProfile();
        expect(profile?.language).toBe('en');
      } finally {
        await ctx.close();
        // Reset language to de so subsequent tests start clean
        await patchLanguage('de');
      }
    },
  );

  // ==========================================================================
  // Test 2: language preference persists over logout/login
  // ==========================================================================
  test(
    'language preference in user_profiles.language persists over logout/login',
    async ({ browser }) => {
      // Set language = "en" via API so we have a known saved preference
      await patchLanguage('en');

      // Verify DB has "en" before the login
      const preProfile = await fetchProfile();
      expect(preProfile?.language).toBe('en');

      // Open a fresh context — no stored session (simulates fresh login)
      const freshCtx = await browser.newContext();
      const page = await freshCtx.newPage();
      try {
        // Navigate to app — AuthPage should show (no session)
        await page.goto(BASE_URL);
        await waitForFlutter(page);

        // Perform UI login
        await page.getByLabel('E-Mail').fill(process.env.TEST_EMAIL ?? 'alex@alexstuder.ch');
        await page.getByLabel('Passwort').fill(process.env.TEST_PASSWORD ?? 'asdf');
        await page.getByRole('button', { name: /Anmelden/ }).click();
        await waitForFlutter(page);

        // Wait for BrewEntryPage (confirms login succeeded)
        await expect(
          page.getByRole('button', { name: /Users profil/i }),
        ).toBeVisible({ timeout: 15_000 });

        // Navigate to UserProfilePage
        await page.getByRole('button', { name: /Users profil/i }).click();
        await waitForFlutter(page);
        await expect(
          page.getByRole('button', { name: /Profil speichern|Save Profile/i }),
        ).toBeVisible({ timeout: 15_000 });

        // The app should have loaded "en" from user_profiles.language on boot.
        // "Water profiles" (en) should be present instead of "Wasserprofile" (de).
        await expect(
          page.getByRole('button', { name: /Water profiles/i }),
        ).toBeVisible({ timeout: 10_000 });

        // Double-check: "Wasserprofile" (de) must NOT be visible
        await expect(
          page.getByRole('button', { name: /^Wasserprofile$/i }),
        ).not.toBeVisible({ timeout: 3_000 });
      } finally {
        await freshCtx.close();
        // Always restore to de so subsequent test runs start from a German UI
        await patchLanguage('de');
      }
    },
  );
});
