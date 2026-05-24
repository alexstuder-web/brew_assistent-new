/**
 * Suite 11: Visual Regression
 *
 * Scope: Snapshot baselines for the 5 most important pages at 1280x800.
 *        Catches CanvasKit rendering drift on theme or layout changes.
 *
 * Pages covered:
 *   1. AuthPage          — unauthenticated entry point
 *   2. BrewEntryPage     — post-login landing
 *   3. UserProfilePage   — /user-profile
 *   4. IntegrationsPage  — reached via UserProfile → Integrationen
 *   5. RecipeResultPage  — reached via seeded ai_generated_recipes_v2 row + list click
 *
 * RecipeResultPage strategy:
 *   page.route() mocking is unreliable for Flutter's Dart HTTP client (XHR via
 *   ServiceWorker is not interceptable by Playwright's network layer).
 *   Instead we seed a deterministic row via Supabase REST before the test and
 *   navigate to the detail view via the GeneratedRecipesListPage. The seeded row
 *   is cleaned up in afterAll.
 *
 * Baseline generation:
 *   First run: `--update-snapshots` (or simply first run when no baseline exists)
 *   creates the PNG files under tests/visual/snapshot.spec.ts-snapshots/.
 *   Subsequent runs diff against these baselines.
 *
 * Stability waits:
 *   waitForFlutter() + an extra waitForTimeout(800) before each screenshot gives
 *   CanvasKit's rasterisation pipeline time to settle. Without the extra wait,
 *   fonts or icons may not be fully painted, causing spurious diffs.
 *
 * .gitignore decision — see report.
 */

import { test, expect, request as playwrightRequest, APIRequestContext } from '@playwright/test';
import { waitForFlutter } from '../../fixtures/flutter-a11y';
import { apiLogin, STORAGE_STATE } from '../../fixtures/auth';
import { cleanupE2ERecipes, TEST_USER_UUID } from '../../fixtures/db-cleanup';

test.describe.configure({ mode: 'serial' });

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:8081';
const SUPABASE_URL = process.env.SUPABASE_URL ?? 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? '';

// Shared REST context for seeding / cleanup
let apiCtx: APIRequestContext;
let token: string;

// Name for the seeded recipe row — stable string so baselines are deterministic
const VISUAL_RECIPE_NAME = 'e2e-visual-snapshot';

test.beforeAll(async () => {
  apiCtx = await playwrightRequest.newContext();
  token = await apiLogin(apiCtx);
  // Clean up any leftover e2e visual recipes from a previous aborted run
  await cleanupE2ERecipes(apiCtx, token);
  await seedVisualRecipe();
});

test.afterAll(async () => {
  await cleanupE2ERecipes(apiCtx, token);
  await apiCtx.dispose();
});

// ---------------------------------------------------------------------------
// Seed helper
// ---------------------------------------------------------------------------

async function seedVisualRecipe(): Promise<void> {
  const data = {
    user_profile_id: TEST_USER_UUID,
    basis_bier: VISUAL_RECIPE_NAME,
    bier_typ: 'Pale Ale',
    ibu: 35,
    malts: [{ name: 'Pale Malt', amount_kg: 4.0, crush_gap_mm: 1.2 }],
    hops: [
      { name: 'Cascade', alpha_acid: 5.5, amount_g: 30, use_type: 'Kochen', time_min: 60 },
    ],
    yeast_name: 'US-05',
    yeast_type: 'Trocken',
    yeast_amount: '1 Pkg',
    mash_steps: [],
    fermentation_steps: [],
    specials: [],
    finings: [],
  };

  const res = await apiCtx.post(`${SUPABASE_URL}/rest/v1/ai_generated_recipes_v2`, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${token}`,
      'Accept-Profile': 'aibrewgenius',
      'Content-Profile': 'aibrewgenius',
      'Content-Type': 'application/json',
      Prefer: 'return=representation',
    },
    data,
  });

  if (!res.ok()) {
    const body = await res.text();
    throw new Error(`[visual] seedVisualRecipe failed (${res.status()}): ${body}`);
  }
}

// ---------------------------------------------------------------------------
// Navigation helpers (reuse patterns from other suites)
// ---------------------------------------------------------------------------

async function openBrewEntryPage(page: import('@playwright/test').Page): Promise<void> {
  await page.goto(BASE_URL);
  await waitForFlutter(page);
  await expect(
    page.getByRole('button', { name: /Users profil/i }),
  ).toBeVisible({ timeout: 15_000 });
}

async function openUserProfilePage(page: import('@playwright/test').Page): Promise<void> {
  await openBrewEntryPage(page);
  await page.getByRole('button', { name: /Users profil/i }).click();
  await waitForFlutter(page);
  await expect(
    page.getByRole('button', { name: /Profil speichern|Save Profile/i }),
  ).toBeVisible({ timeout: 15_000 });
}

async function openIntegrationsPage(page: import('@playwright/test').Page): Promise<void> {
  await page.goto(BASE_URL);
  await waitForFlutter(page);

  await expect(page.getByRole('button', { name: /Users profil/i })).toBeVisible({ timeout: 15_000 });
  await page.getByRole('button', { name: /Users profil/i }).click();
  await waitForFlutter(page);
  // Wait for profile data to populate (same pattern as integrations.spec.ts)
  await page.waitForTimeout(1_000);
  await waitForFlutter(page);

  // Button label in app_de.arb is "Integration" (not "Integrationen")
  await expect(page.getByRole('button', { name: /Integration/i })).toBeVisible({ timeout: 10_000 });
  await page.getByRole('button', { name: /Integration/i }).click();
  await page.waitForTimeout(500);
  await waitForFlutter(page);

  // IntegrationsPage AppBar title "Integrationen"
  await expect(page.getByText('Integrationen')).toBeVisible({ timeout: 10_000 });
  // Give data time to load from DB
  await page.waitForTimeout(1_000);
  await waitForFlutter(page);
}

async function openRecipeResultPage(page: import('@playwright/test').Page): Promise<void> {
  await openBrewEntryPage(page);
  // Navigate via Users profil → Generierte Rezepte → click the seeded row
  await page.getByRole('button', { name: /Users profil/i }).click();
  await waitForFlutter(page);
  await page.waitForTimeout(1_000);
  await waitForFlutter(page);

  await expect(
    page.getByRole('button', { name: /Generierte Rezepte/i }),
  ).toBeVisible({ timeout: 10_000 });
  await page.getByRole('button', { name: /Generierte Rezepte/i }).click();
  await page.waitForTimeout(1_500);
  await waitForFlutter(page);
  await page.waitForTimeout(800);
  await waitForFlutter(page);

  // Find and click the seeded recipe row
  const recipeNameEsc = VISUAL_RECIPE_NAME.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const recipeBtn = page.getByRole('button', { name: new RegExp(recipeNameEsc, 'i') });
  await expect(recipeBtn).toBeVisible({ timeout: 10_000 });
  await recipeBtn.click();
  await waitForFlutter(page);
  await page.waitForTimeout(800);

  // RecipeResultPage — wait for the tab bar to confirm we're on the right page
  await expect(
    page.getByRole('tab', { name: /Übersicht/i }),
  ).toBeVisible({ timeout: 10_000 });
}

// ---------------------------------------------------------------------------
// Snapshot tests
// ---------------------------------------------------------------------------

// CanvasKit render stabilisation: extra wait beyond waitForFlutter to allow
// the GPU rasteriser to flush all layers before toHaveScreenshot captures.
const RENDER_SETTLE_MS = 800;

test('AuthPage @ 1280x800 — baseline', async ({ page }) => {
  // Use an unauthenticated context (default page fixture, no storageState)
  await page.goto(BASE_URL);
  await waitForFlutter(page);

  // Wait for the login form to be fully painted
  await expect(page.getByLabel('E-Mail')).toBeVisible({ timeout: 10_000 });
  await page.waitForTimeout(RENDER_SETTLE_MS);

  await expect(page).toHaveScreenshot('auth-page.png');
});

test('BrewEntryPage @ 1280x800 — baseline', async ({ browser }) => {
  const ctx = await browser.newContext({ storageState: STORAGE_STATE });
  const page = await ctx.newPage();
  try {
    await openBrewEntryPage(page);
    await page.waitForTimeout(RENDER_SETTLE_MS);
    await expect(page).toHaveScreenshot('brew-entry-page.png');
  } finally {
    await ctx.close();
  }
});

test('UserProfilePage @ 1280x800 — baseline', async ({ browser }) => {
  const ctx = await browser.newContext({ storageState: STORAGE_STATE });
  const page = await ctx.newPage();
  try {
    await openUserProfilePage(page);
    await page.waitForTimeout(RENDER_SETTLE_MS);
    await expect(page).toHaveScreenshot('user-profile-page.png');
  } finally {
    await ctx.close();
  }
});

test('IntegrationsPage @ 1280x800 — baseline', async ({ browser }) => {
  const ctx = await browser.newContext({ storageState: STORAGE_STATE });
  const page = await ctx.newPage();
  try {
    await openIntegrationsPage(page);
    await page.waitForTimeout(RENDER_SETTLE_MS);
    await expect(page).toHaveScreenshot('integrations-page.png');
  } finally {
    await ctx.close();
  }
});

test('RecipeResultPage @ 1280x800 — baseline', async ({ browser }) => {
  // Strategy: navigate to the seeded recipe via GeneratedRecipesListPage.
  // page.route() mocking is not used (Flutter Dart HTTP client is not interceptable
  // by Playwright's network layer — see profile.spec.ts comment block).
  // A deterministic row is seeded in beforeAll with a fixed name to keep the
  // baseline stable across runs (same recipe content = same pixels, modulo
  // CanvasKit font hinting which is absorbed by threshold:0.2).
  const ctx = await browser.newContext({ storageState: STORAGE_STATE });
  const page = await ctx.newPage();
  try {
    await openRecipeResultPage(page);
    await page.waitForTimeout(RENDER_SETTLE_MS);
    await expect(page).toHaveScreenshot('recipe-result-page.png');
  } finally {
    await ctx.close();
  }
});
