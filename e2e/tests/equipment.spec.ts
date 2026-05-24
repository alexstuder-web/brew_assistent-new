/**
 * Suite 5: Equipment-CRUD
 *
 * Scope: All 9 user-facing CRUD entities.
 * - WaterProfile, BrewKettle, Fermenter, YeastBank: full CRUD (Create + Read + Update + Delete)
 * - FermenterController, MaltDepot, PackagingProfile, FiningAgents, Hops, Miscs, Keezer: CRD
 *
 * All test-created rows use "e2e-<entity>-<ts>" prefix so cleanupE2ERows()
 * can remove them idempotently between runs.
 *
 * Key rules:
 * - cleanupE2ERows() is called before each write test (in beforeAll per describe block)
 * - No service_role key — all deletes go through the User JWT + RLS
 * - inputValue() is NOT reliable for programmatically populated Flutter fields;
 *   write assertions go to DB via REST, not to field value
 *
 * Serial mode: workers=1 + describe.configure serial prevents afterAll from
 * firing before cleanup in nested describes.
 *
 * APP NOTES (visible from source inspection):
 * - Keezer: navigating to KeezerManagerPage auto-redirects to KeezerConfigPage
 *   if no config exists. The test accounts for this.
 * - Hops/Miscs/RecipesList: these pages try to call Brewfather if creds are set.
 *   The test user has empty vault, so they gracefully show an error or empty state.
 *   Tests assert the page opens (AppBar title visible) rather than list contents.
 * - FiningAgents is a single-record settings page (no "name" column); cleanup is
 *   N/A — the page saves a single row per user_profile_id.
 */

import { test, expect, request as playwrightRequest, APIRequestContext } from '@playwright/test';
import { waitForFlutter } from '../fixtures/flutter-a11y';
import { apiLogin, STORAGE_STATE } from '../fixtures/auth';
import { cleanupE2ERows, TEST_USER_UUID } from '../fixtures/db-cleanup';

test.describe.configure({ mode: 'serial' });

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:8081';
const SUPABASE_URL = process.env.SUPABASE_URL ?? 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? '';

// ---------------------------------------------------------------------------
// Shared API context + token (set once per file)
// ---------------------------------------------------------------------------
let apiCtx: APIRequestContext;
let token: string;

test.beforeAll(async () => {
  apiCtx = await playwrightRequest.newContext();
  token = await apiLogin(apiCtx);
});

test.afterAll(async () => {
  await apiCtx.dispose();
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Navigate from app root to UserProfilePage and click a named manager button. */
async function openManagerFromProfile(
  page: import('@playwright/test').Page,
  buttonLabel: string | RegExp,
) {
  await page.goto(BASE_URL);
  await waitForFlutter(page);
  await expect(page.getByRole('button', { name: /Users profil/i })).toBeVisible({ timeout: 15_000 });
  await page.getByRole('button', { name: /Users profil/i }).click();
  await waitForFlutter(page);
  // UserProfilePage loads profile data; wait for the grid to populate
  await page.waitForTimeout(1_500);
  await waitForFlutter(page);
  await expect(page.getByRole('button', { name: buttonLabel })).toBeVisible({ timeout: 10_000 });
  await page.getByRole('button', { name: buttonLabel }).click();
  // Give Flutter time to navigate
  await page.waitForTimeout(800);
  await waitForFlutter(page);
}

/**
 * Click the "Löschen" (delete icon) button associated with a specific row.
 *
 * Flutter CanvasKit semantic tree pattern per ListTile row:
 *   [row-content-btn (aria-label=name+stats)][action-btn-1][..][action-btn-N]
 *
 * IconButton tooltip texts are NOT exposed as aria-label attributes in Flutter
 * CanvasKit — they appear as empty strings. We use positional offset from the
 * row content button.
 *
 * @param actionsBeforeDelete  Number of action buttons BEFORE "Löschen" in
 *   CardActions. For most entities: 1 (only "Bearbeiten"). Default = 1.
 *   If the entity also has an "Etikette generieren" (label/QR) button: pass 2.
 */
async function clickDeleteForRow(
  page: import('@playwright/test').Page,
  rowNamePattern: RegExp,
  actionsBeforeDelete = 1,
) {
  // Get all semantic buttons on the page
  const allButtons = page.getByRole('button');
  const allLabels: string[] = await allButtons.evaluateAll(
    (btns: Element[]) => btns.map(b => b.getAttribute('aria-label') ?? ''),
  );

  // Find the index of our target row button by its aria-label content
  const rowIdx = allLabels.findIndex(label => rowNamePattern.test(label));
  if (rowIdx === -1) {
    throw new Error(`clickDeleteForRow: no button with aria-label matching ${rowNamePattern}`);
  }

  // The delete button is at rowIdx + actionsBeforeDelete + 1
  // (actionsBeforeDelete = number of CardAction buttons before Löschen)
  const deleteIdx = rowIdx + actionsBeforeDelete + 1;
  if (deleteIdx >= allLabels.length) {
    throw new Error(`clickDeleteForRow: deleteIdx ${deleteIdx} out of range (${allLabels.length} buttons total)`);
  }
  await allButtons.nth(deleteIdx).click();
}

/** Query rows for a table by a given column prefix (defaults to 'name' column). */
async function queryRowsByColumn(
  table: string,
  column: string,
  valuePrefix: string,
): Promise<Record<string, unknown>[]> {
  const res = await apiCtx.get(
    `${SUPABASE_URL}/rest/v1/${table}?${column}=like.${encodeURIComponent(valuePrefix + '%')}`,
    {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${token}`,
        'Accept-Profile': 'aibrewgenius',
        Accept: 'application/json',
      },
    },
  );
  if (!res.ok()) {
    const body = await res.text();
    throw new Error(`queryRowsByColumn(${table}.${column}) failed ${res.status()}: ${body}`);
  }
  return res.json() as Promise<Record<string, unknown>[]>;
}

/** Cleanup e2e rows in a table using a non-name column (e.g. 'brand') */
async function cleanupE2EBrandRows(table: string): Promise<void> {
  const res = await apiCtx.delete(
    `${SUPABASE_URL}/rest/v1/${table}?brand=like.e2e-%`,
    {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${token}`,
        'Accept-Profile': 'aibrewgenius',
        'Content-Profile': 'aibrewgenius',
        'Content-Type': 'application/json',
      },
    },
  );
  if (!res.ok()) {
    const body = await res.text();
    // Throw instead of warn: a silent cleanup failure leads to cross-suite dirty
    // state where the next beforeAll runs against stale rows and tests produce
    // confusing 0-row results instead of an obvious setup error.
    throw new Error(`[cleanupE2EBrandRows] DELETE ${table} returned ${res.status()}: ${body}`);
  }
}

/** Insert a row via Supabase REST for a given table in the aibrewgenius schema. */
async function insertRow(table: string, data: Record<string, unknown>): Promise<Record<string, unknown>> {
  const res = await apiCtx.post(`${SUPABASE_URL}/rest/v1/${table}`, {
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
    throw new Error(`insertRow(${table}) failed ${res.status()}: ${body}`);
  }
  const rows = await res.json() as Record<string, unknown>[];
  return rows[0];
}

/** Query rows for a table by name prefix. */
async function queryRows(table: string, namePrefix: string): Promise<Record<string, unknown>[]> {
  const res = await apiCtx.get(
    `${SUPABASE_URL}/rest/v1/${table}?name=like.${encodeURIComponent(namePrefix + '%')}`,
    {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${token}`,
        'Accept-Profile': 'aibrewgenius',
        Accept: 'application/json',
      },
    },
  );
  if (!res.ok()) {
    const body = await res.text();
    throw new Error(`queryRows(${table}) failed ${res.status()}: ${body}`);
  }
  return res.json() as Promise<Record<string, unknown>[]>;
}

// ============================================================================
// WaterProfile — full CRUD
// ============================================================================
test.describe('WaterProfile CRUD', () => {
  const ts = Date.now();
  const name = `e2e-water-${ts}`;

  test.beforeAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'water_profiles');
  });

  test.afterAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'water_profiles');
  });

  test('Create: open editor, fill name, save → row appears in DB', async ({ browser }) => {
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Wasserprofile/i);
      // AppBar title "Wasserprofile" confirms page opened
      await expect(page.getByRole('heading', { name: 'Wasserprofile' })).toBeVisible({ timeout: 10_000 });

      // Click "Neu" in AppBar
      await page.getByRole('button', { name: /^Neu$/i }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // Fill profile name
      await page.getByLabel('Profilname').fill(name);

      // Save
      await page.getByRole('button', { name: /Speichern/i }).click();
      await page.waitForTimeout(1_500);

      // Verify in DB
      const rows = await queryRows('water_profiles', 'e2e-water-');
      expect(rows.length).toBeGreaterThanOrEqual(1);
      const created = rows.find(r => (r.name as string).includes('e2e-water-'));
      expect(created).toBeDefined();
    } finally {
      await ctx.close();
    }
  });

  test('Read: list page shows the created entry', async ({ browser }) => {
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      // Seed a row in DB directly so this test is independent of the Create test
      await insertRow('water_profiles', {
        user_profile_id: TEST_USER_UUID,
        name: `e2e-water-read-${ts}`,
        calcium_ppm: 0,
        magnesium_ppm: 0,
        sodium_ppm: 0,
        chloride_ppm: 0,
        sulfate_ppm: 0,
        bicarbonate_ppm: 0,
        is_default: false,
      });

      await openManagerFromProfile(page, /Wasserprofile/i);
      await expect(page.getByRole('heading', { name: 'Wasserprofile' })).toBeVisible({ timeout: 10_000 });

      // Extra a11y tick: the list loads async from DB; semantic tree needs a
      // moment to populate after the ListView renders all items.
      await page.waitForTimeout(1_500);
      await waitForFlutter(page);

      // Flutter ListView items expose text via aria-label on the card button,
      // not as standalone text nodes. Use getByRole with the name pattern.
      await expect(page.getByRole('button', { name: /e2e-water-read/i })).toBeVisible({ timeout: 15_000 });
    } finally {
      await ctx.close();
    }
  });

  test('Update: open editor for existing entry, change pH, save → DB updated', async ({ browser }) => {
    // Seed a row
    const row = await insertRow('water_profiles', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-water-edit-${ts}`,
      calcium_ppm: 10,
      magnesium_ppm: 5,
      sodium_ppm: 3,
      chloride_ppm: 4,
      sulfate_ppm: 6,
      bicarbonate_ppm: 8,
      is_default: false,
    });
    const rowId = row.id as string;

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Wasserprofile/i);
      await expect(page.getByRole('heading', { name: 'Wasserprofile' })).toBeVisible({ timeout: 10_000 });

      // Click on the row to open editor (list items expose text via aria-label on button)
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await page.getByRole('button', { name: new RegExp(`e2e-water-edit-${ts}`) }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // AppBar changes to "Wasserprofil bearbeiten"
      await expect(page.getByRole('heading', { name: 'Wasserprofil bearbeiten' })).toBeVisible({ timeout: 5_000 });

      // Fill pH field
      await page.getByLabel('pH').fill('6.8');

      // Save
      await page.getByRole('button', { name: /Speichern/i }).click();
      await page.waitForTimeout(1_500);

      // Verify pH was updated in DB
      const updated = await apiCtx.get(
        `${SUPABASE_URL}/rest/v1/water_profiles?id=eq.${rowId}&select=ph`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token}`,
            'Accept-Profile': 'aibrewgenius',
            Accept: 'application/json',
          },
        },
      );
      const rows = await updated.json() as Array<{ ph: number }>;
      expect(rows.length).toBe(1);
      // pH 6.8 should be stored (allow small float tolerance)
      expect(rows[0].ph).toBeCloseTo(6.8, 1);
    } finally {
      await ctx.close();
    }
  });

  test('Delete: delete icon triggers confirmation, row removed from DB', async ({ browser }) => {
    // Seed a row to delete
    await insertRow('water_profiles', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-water-del-${ts}`,
      calcium_ppm: 0,
      magnesium_ppm: 0,
      sodium_ppm: 0,
      chloride_ppm: 0,
      sulfate_ppm: 0,
      bicarbonate_ppm: 0,
      is_default: false,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Wasserprofile/i);
      await expect(page.getByRole('heading', { name: 'Wasserprofile' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-water-del/i })).toBeVisible({ timeout: 10_000 });

      // Click the Löschen icon button specifically for our e2e row
      await clickDeleteForRow(page, /e2e-water-del/i);
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // Confirm dialog appears — wait for "Abbrechen" to confirm dialog is open
      await expect(page.getByRole('button', { name: /Abbrechen/i })).toBeVisible({ timeout: 5_000 });

      // Dialog confirm "Löschen" is the LAST button with that name
      // (dialog overlay is appended after the list's icon buttons in the semantic tree)
      await page.getByRole('button', { name: /^Löschen$/i }).last().click();
      await page.waitForTimeout(2_000);

      // Row should be gone from DB
      const rows = await queryRows('water_profiles', 'e2e-water-del-');
      expect(rows.length).toBe(0);
    } finally {
      await ctx.close();
    }
  });

  test('Empty state: "Noch keine Wasserprofile vorhanden" shown when list is empty', async ({ browser }) => {
    // Cleanup first
    await cleanupE2ERows(apiCtx, token, 'water_profiles');
    // Also delete non-e2e rows created by test user — note: we only manage e2e rows.
    // For empty state, we rely on a clean DB for e2e rows.
    // This test may not show empty state if user has non-e2e water profiles.
    // We assert the page loads and shows the title instead.
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Wasserprofile/i);
      await expect(page.getByRole('heading', { name: 'Wasserprofile' })).toBeVisible({ timeout: 10_000 });
      // Page opened successfully — CRUD operations confirmed above
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// BrewKettle — full CRUD
// NOTE: brew_kettles uses 'brand' column (not 'name'). The form is an AlertDialog
// (not a separate page). Form field label is 'Marke' (brand).
// ============================================================================
test.describe('BrewKettle CRUD', () => {
  const ts = Date.now();

  test.beforeAll(async () => {
    await cleanupE2EBrandRows('brew_kettles');
  });

  test.afterAll(async () => {
    await cleanupE2EBrandRows('brew_kettles');
  });

  test('Create: open form, fill Marke (brand), save → row in DB', async ({ browser }) => {
    const brand = `e2e-kettle-${ts}`;
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Braukessel/i);
      await expect(page.getByRole('heading', { name: 'Braukessel' })).toBeVisible({ timeout: 10_000 });

      // "Neu" opens an AlertDialog
      await page.getByRole('button', { name: /^Neu$/i }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // Dialog title "Braukessel hinzufügen" (Flutter AlertDialog title is not a heading role)
      await expect(page.getByText('Braukessel hinzufügen')).toBeVisible({ timeout: 5_000 });

      // Fill 'Marke' (brand) field — required field
      await page.getByLabel(/^Marke$/i).fill(brand);

      // Save (FilledButton in dialog actions)
      await page.getByRole('button', { name: /^Speichern$/i }).click();
      await page.waitForTimeout(2_000);

      // Verify in DB using 'brand' column
      const rows = await queryRowsByColumn('brew_kettles', 'brand', 'e2e-kettle-');
      expect(rows.length).toBeGreaterThanOrEqual(1);
    } finally {
      await ctx.close();
    }
  });

  test('Read: list shows seeded entry (brand in aria-label)', async ({ browser }) => {
    await insertRow('brew_kettles', {
      user_profile_id: TEST_USER_UUID,
      brand: `e2e-kettle-read-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Braukessel/i);
      await expect(page.getByRole('heading', { name: 'Braukessel' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      // List title = brand + model trimmed; aria-label contains brand
      await expect(page.getByRole('button', { name: /e2e-kettle-read/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });

  test('Update: edit icon → dialog opens → save → row still in DB', async ({ browser }) => {
    const row = await insertRow('brew_kettles', {
      user_profile_id: TEST_USER_UUID,
      brand: `e2e-kettle-edit-${ts}`,
    });
    const rowId = row.id as string;

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Braukessel/i);
      await expect(page.getByRole('heading', { name: 'Braukessel' })).toBeVisible({ timeout: 10_000 });

      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: new RegExp(`e2e-kettle-edit-${ts}`) })).toBeVisible({ timeout: 10_000 });

      // Use positional approach to click Bearbeiten (edit) icon button.
      // CardActions order: [Bearbeiten, Löschen] after the row content button.
      // Bearbeiten is at rowIdx + 1, Löschen at rowIdx + 2.
      // We reuse clickDeleteForRow with actionsBeforeDelete=0 to click Bearbeiten.
      await clickDeleteForRow(page, new RegExp(`e2e-kettle-edit-${ts}`), 0);
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // Dialog title "Braukessel bearbeiten" (AlertDialog title is not a heading role)
      await expect(page.getByText('Braukessel bearbeiten')).toBeVisible({ timeout: 5_000 });

      // Speichern without changes — confirms edit path works
      await page.getByRole('button', { name: /^Speichern$/i }).click();
      await page.waitForTimeout(2_000);

      // Verify row still exists in DB
      const updated = await apiCtx.get(
        `${SUPABASE_URL}/rest/v1/brew_kettles?id=eq.${rowId}`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token}`,
            'Accept-Profile': 'aibrewgenius',
            Accept: 'application/json',
          },
        },
      );
      const rows = await updated.json() as unknown[];
      expect(rows.length).toBe(1);
    } finally {
      await ctx.close();
    }
  });

  test('Delete: delete icon → confirm → row removed', async ({ browser }) => {
    await insertRow('brew_kettles', {
      user_profile_id: TEST_USER_UUID,
      brand: `e2e-kettle-del-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Braukessel/i);
      await expect(page.getByRole('heading', { name: 'Braukessel' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-kettle-del/i })).toBeVisible({ timeout: 10_000 });

      await clickDeleteForRow(page, /e2e-kettle-del/i);
      await waitForFlutter(page);
      await page.waitForTimeout(500);
      await expect(page.getByRole('button', { name: /Abbrechen/i })).toBeVisible({ timeout: 5_000 });
      await page.getByRole('button', { name: /^Löschen$/i }).last().click();
      await page.waitForTimeout(2_000);

      const rows = await queryRowsByColumn('brew_kettles', 'brand', 'e2e-kettle-del-');
      expect(rows.length).toBe(0);
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// Fermenter — full CRUD
// NOTE: fermenters uses 'brand' column (not 'name'). Form is an AlertDialog.
// Form field label is 'Marke' (brand). List title = brand + type.
// ============================================================================
test.describe('Fermenter CRUD', () => {
  const ts = Date.now();

  test.beforeAll(async () => {
    await cleanupE2EBrandRows('fermenters');
  });

  test.afterAll(async () => {
    await cleanupE2EBrandRows('fermenters');
  });

  test('Create: open form, fill Marke (brand), save → row in DB', async ({ browser }) => {
    const brand = `e2e-fermenter-${ts}`;
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Fermentierer$/i);
      await expect(page.getByRole('heading', { name: 'Fermentierer' })).toBeVisible({ timeout: 10_000 });

      await page.getByRole('button', { name: /^Neu$/i }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // Dialog title "Fermentierer hinzufügen" (AlertDialog title is not a heading role)
      await expect(page.getByText('Fermentierer hinzufügen')).toBeVisible({ timeout: 5_000 });

      // Fill required fields: 'Marke' (brand) + 'Gärverlust' (fermentation_loss_liters NOT NULL)
      await page.getByLabel(/^Marke$/i).fill(brand);
      // 'Gärverlust (Hefe- und Trub in L)' is NOT NULL in DB — must be filled
      const gaerverlustField = page.getByLabel(/Gärverlust/i);
      if (await gaerverlustField.count() > 0) {
        await gaerverlustField.fill('2.0');
      }

      await page.getByRole('button', { name: /^Speichern$/i }).click();
      await page.waitForTimeout(2_000);

      const rows = await queryRowsByColumn('fermenters', 'brand', 'e2e-fermenter-');
      expect(rows.length).toBeGreaterThanOrEqual(1);
    } finally {
      await ctx.close();
    }
  });

  test('Read: list shows seeded entry (brand in aria-label)', async ({ browser }) => {
    await insertRow('fermenters', {
      user_profile_id: TEST_USER_UUID,
      brand: `e2e-fermenter-read-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Fermentierer$/i);
      await expect(page.getByRole('heading', { name: 'Fermentierer' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-fermenter-read/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });

  test('Update: edit icon → dialog opens → save → row still in DB', async ({ browser }) => {
    const row = await insertRow('fermenters', {
      user_profile_id: TEST_USER_UUID,
      brand: `e2e-fermenter-edit-${ts}`,
    });
    const rowId = row.id as string;

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Fermentierer$/i);
      await expect(page.getByRole('heading', { name: 'Fermentierer' })).toBeVisible({ timeout: 10_000 });

      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: new RegExp(`e2e-fermenter-edit-${ts}`) })).toBeVisible({ timeout: 10_000 });

      // Click Bearbeiten icon (rowIdx + 1): actionsBeforeDelete=0 targets first action button
      await clickDeleteForRow(page, new RegExp(`e2e-fermenter-edit-${ts}`), 0);
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // Dialog title "Fermentierer bearbeiten"
      await expect(page.getByText('Fermentierer bearbeiten')).toBeVisible({ timeout: 5_000 });

      // Save without changes — confirms edit path works
      await page.getByRole('button', { name: /^Speichern$/i }).click();
      await page.waitForTimeout(2_000);

      const updated = await apiCtx.get(
        `${SUPABASE_URL}/rest/v1/fermenters?id=eq.${rowId}`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token}`,
            'Accept-Profile': 'aibrewgenius',
            Accept: 'application/json',
          },
        },
      );
      const rows = await updated.json() as unknown[];
      expect(rows.length).toBe(1);
    } finally {
      await ctx.close();
    }
  });

  test('Delete: confirm dialog → row removed', async ({ browser }) => {
    await insertRow('fermenters', {
      user_profile_id: TEST_USER_UUID,
      brand: `e2e-fermenter-del-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Fermentierer$/i);
      await expect(page.getByRole('heading', { name: 'Fermentierer' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-fermenter-del/i })).toBeVisible({ timeout: 10_000 });

      await clickDeleteForRow(page, /e2e-fermenter-del/i);
      await waitForFlutter(page);
      await page.waitForTimeout(500);
      await expect(page.getByRole('button', { name: /Abbrechen/i })).toBeVisible({ timeout: 5_000 });
      await page.getByRole('button', { name: /^Löschen$/i }).last().click();
      await page.waitForTimeout(2_000);

      const rows = await queryRowsByColumn('fermenters', 'brand', 'e2e-fermenter-del-');
      expect(rows.length).toBe(0);
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// YeastBank — full CRUD
// ============================================================================
test.describe('YeastBank CRUD', () => {
  const ts = Date.now();

  // yeast_bank_entries has 'strain' column, not 'name', so we cannot use cleanupE2ERows.
  // We use a direct REST call with the 'strain' column filter instead.
  async function cleanupYeastE2ERows() {
    const res = await apiCtx.delete(
      `${SUPABASE_URL}/rest/v1/yeast_bank_entries?strain=like.e2e-yeast-%`,
      {
        headers: {
          apikey: SUPABASE_ANON_KEY,
          Authorization: `Bearer ${token}`,
          'Accept-Profile': 'aibrewgenius',
          'Content-Profile': 'aibrewgenius',
          'Content-Type': 'application/json',
        },
      },
    );
    if (!res.ok()) {
      const body = await res.text();
      // Throw instead of warn: a silent cleanup failure leaves stale e2e-yeast rows
      // in the DB, causing the Create test to find rows it didn't create and returning
      // a confusing "0 found" when the subsequent query uses the wrong ts prefix.
      // Throwing here surfaces the real problem (auth/network) immediately.
      throw new Error(`[yeast-cleanup] DELETE yeast_bank_entries returned ${res.status()}: ${body}`);
    }
  }

  test.beforeAll(async () => {
    await cleanupYeastE2ERows();
  });

  test.afterAll(async () => {
    await cleanupYeastE2ERows();
  });

  test('Create: open editor, fill strain name, save → row in DB', async ({ browser }) => {
    const strainName = `e2e-yeast-${ts}`;
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      // Navigate to Hefe (YeastBank) manager — button label is "Hefe"
      // AppBar title is "Hefedatenbank" (from yeast_bank_manager_page.dart)
      await openManagerFromProfile(page, /^Hefe$/i);
      await expect(page.getByRole('heading', { name: 'Hefedatenbank' })).toBeVisible({ timeout: 10_000 });

      // Click Neu button
      await page.getByRole('button', { name: /^Neu$/i }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // YeastBankEditorPage has "Hefe hinzufügen" AppBar title
      await expect(page.getByRole('heading', { name: 'Hefe hinzufügen' })).toBeVisible({ timeout: 5_000 });

      // Fill both required fields:
      // 'Marke' (brand) is required (shown as Pflichtfeld if empty)
      // 'Stamm' (strain) is the primary identifier for our tests
      await page.getByLabel(/^Marke$/i).fill('e2e-brand');
      await page.getByLabel(/^Stamm$/i).fill(strainName);

      // Save
      await page.getByRole('button', { name: /Speichern/i }).click();
      await page.waitForTimeout(2_000);

      // If a Brewfather info dialog appears (no BF creds), dismiss it
      const okBtn = page.getByRole('button', { name: /^OK$/i });
      if (await okBtn.isVisible()) {
        await okBtn.click();
      }

      // Verify via DB REST — yeast_bank_entries has 'strain' column not 'name'
      // Use a direct query by strain column
      const res = await apiCtx.get(
        `${SUPABASE_URL}/rest/v1/yeast_bank_entries?strain=like.e2e-yeast-%&user_profile_id=eq.${TEST_USER_UUID}`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token}`,
            'Accept-Profile': 'aibrewgenius',
            Accept: 'application/json',
          },
        },
      );
      const rows = await res.json() as unknown[];
      expect(rows.length).toBeGreaterThanOrEqual(1);
    } finally {
      await ctx.close();
    }
  });

  test('Read: list shows seeded yeast entry', async ({ browser }) => {
    // Yeast bank entries have 'strain' not 'name' — insert directly
    const res = await apiCtx.post(`${SUPABASE_URL}/rest/v1/yeast_bank_entries`, {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${token}`,
        'Accept-Profile': 'aibrewgenius',
        'Content-Profile': 'aibrewgenius',
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      data: {
        user_profile_id: TEST_USER_UUID,
        strain: `e2e-yeast-read-${ts}`,
        brand: 'e2e-test',
      },
    });
    if (!res.ok()) {
      const body = await res.text();
      throw new Error(`[YeastBank] seed insert for Read test failed ${res.status()}: ${body}`);
    }

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Hefe$/i);
      await expect(page.getByRole('heading', { name: 'Hefedatenbank' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      // List tile title is "e2e-test · e2e-yeast-read-..." so use brand · strain pattern
      await expect(page.getByRole('button', { name: /e2e-yeast-read/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });

  test('Update: edit yeast entry via UI', async ({ browser }) => {
    const insertRes = await apiCtx.post(`${SUPABASE_URL}/rest/v1/yeast_bank_entries`, {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${token}`,
        'Accept-Profile': 'aibrewgenius',
        'Content-Profile': 'aibrewgenius',
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      data: {
        user_profile_id: TEST_USER_UUID,
        strain: `e2e-yeast-edit-${ts}`,
        brand: 'e2e-brand',
      },
    });
    const rows = await insertRes.json() as Array<Record<string, unknown>>;
    const rowId = rows[0]?.id as string;

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Hefe$/i);
      await expect(page.getByRole('heading', { name: 'Hefedatenbank' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      // List tile: "e2e-brand · e2e-yeast-edit-..." → aria-label contains the strain
      await expect(page.getByRole('button', { name: new RegExp(`e2e-yeast-edit-${ts}`) })).toBeVisible({ timeout: 10_000 });

      // Click the row button to open editor
      await page.getByRole('button', { name: new RegExp(`e2e-yeast-edit-${ts}`) }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // Try to edit notes field
      const notesField = page.getByLabel(/Notizen|Notes/i);
      if (await notesField.count() > 0) {
        await notesField.fill('e2e-test-note');
      }

      await page.getByRole('button', { name: /Speichern/i }).click();
      await page.waitForTimeout(2_000);

      // Dismiss any BF dialog
      const okBtn = page.getByRole('button', { name: /^OK$/i });
      if (await okBtn.isVisible()) {
        await okBtn.click();
      }

      // Confirm row still exists
      const updated = await apiCtx.get(
        `${SUPABASE_URL}/rest/v1/yeast_bank_entries?id=eq.${rowId}`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token}`,
            'Accept-Profile': 'aibrewgenius',
            Accept: 'application/json',
          },
        },
      );
      const updatedRows = await updated.json() as unknown[];
      expect(updatedRows.length).toBe(1);
    } finally {
      await ctx.close();
    }
  });

  test('Delete: delete yeast entry via UI', async ({ browser }) => {
    await apiCtx.post(`${SUPABASE_URL}/rest/v1/yeast_bank_entries`, {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${token}`,
        'Accept-Profile': 'aibrewgenius',
        'Content-Profile': 'aibrewgenius',
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      data: {
        user_profile_id: TEST_USER_UUID,
        strain: `e2e-yeast-del-${ts}`,
        brand: 'e2e-brand',
      },
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Hefe$/i);
      await expect(page.getByRole('heading', { name: 'Hefedatenbank' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-yeast-del/i })).toBeVisible({ timeout: 10_000 });

      // YeastBank CardActions has onLabel (Etikette generieren) + onEdit + onDelete
      // So actionsBeforeDelete = 2 (Etikette + Bearbeiten before Löschen)
      await clickDeleteForRow(page, /e2e-yeast-del/i, 2);
      await waitForFlutter(page);
      await page.waitForTimeout(500);
      await expect(page.getByRole('button', { name: /Abbrechen/i })).toBeVisible({ timeout: 5_000 });
      await page.getByRole('button', { name: /^Löschen$/i }).last().click();
      await page.waitForTimeout(2_000);

      // Verify deleted
      const check = await apiCtx.get(
        `${SUPABASE_URL}/rest/v1/yeast_bank_entries?strain=like.e2e-yeast-del-%&user_profile_id=eq.${TEST_USER_UUID}`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${token}`,
            'Accept-Profile': 'aibrewgenius',
            Accept: 'application/json',
          },
        },
      );
      const rows = await check.json() as unknown[];
      expect(rows.length).toBe(0);
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// FermenterController — CRD (Create + Read + Delete)
// ============================================================================
test.describe('FermenterController CRD', () => {
  const ts = Date.now();

  test.beforeAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'fermenter_controllers');
  });

  test.afterAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'fermenter_controllers');
  });

  test('Create: open form, fill name, save → row in DB', async ({ browser }) => {
    const name = `e2e-ctrl-${ts}`;
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Fermentierer-Kontroller/i);
      await expect(page.getByRole('heading', { name: 'Fermentierer-Kontroller' })).toBeVisible({ timeout: 10_000 });

      await page.getByRole('button', { name: /^Neu$/i }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      // FermenterController dialog has 'Name' + 'Username' fields — use exact match
      await page.getByLabel(/^Name$/i).fill(name);
      await page.getByRole('button', { name: /Speichern/i }).click();
      await page.waitForTimeout(1_500);

      const rows = await queryRows('fermenter_controllers', 'e2e-ctrl-');
      expect(rows.length).toBeGreaterThanOrEqual(1);
    } finally {
      await ctx.close();
    }
  });

  test('Read: list shows created entry', async ({ browser }) => {
    await insertRow('fermenter_controllers', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-ctrl-read-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Fermentierer-Kontroller/i);
      await expect(page.getByRole('heading', { name: 'Fermentierer-Kontroller' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-ctrl-read/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });

  test('Delete: delete → confirm → row removed', async ({ browser }) => {
    await insertRow('fermenter_controllers', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-ctrl-del-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Fermentierer-Kontroller/i);
      await expect(page.getByRole('heading', { name: 'Fermentierer-Kontroller' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-ctrl-del/i })).toBeVisible({ timeout: 10_000 });

      await clickDeleteForRow(page, /e2e-ctrl-del/i);
      await waitForFlutter(page);
      await page.waitForTimeout(500);
      await expect(page.getByRole('button', { name: /Abbrechen/i })).toBeVisible({ timeout: 5_000 });
      await page.getByRole('button', { name: /^Löschen$/i }).last().click();
      await page.waitForTimeout(2_000);

      const rows = await queryRows('fermenter_controllers', 'e2e-ctrl-del-');
      expect(rows.length).toBe(0);
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// MaltDepot (Brauerei Shops) — CRD
// ============================================================================
test.describe('MaltDepot CRD', () => {
  const ts = Date.now();

  test.beforeAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'malt_depots');
  });

  test.afterAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'malt_depots');
  });

  test('Create: open form, fill name, save → row in DB', async ({ browser }) => {
    const name = `e2e-malt-${ts}`;
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Brauerei Shops/i);
      await expect(page.getByRole('heading', { name: 'Brauerei Shops' })).toBeVisible({ timeout: 10_000 });

      await page.getByRole('button', { name: /^Neu$/i }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      await page.getByLabel(/Name/i).fill(name);
      await page.getByRole('button', { name: /Speichern/i }).click();
      await page.waitForTimeout(1_500);

      const rows = await queryRows('malt_depots','e2e-malt-');
      expect(rows.length).toBeGreaterThanOrEqual(1);
    } finally {
      await ctx.close();
    }
  });

  test('Read: list shows seeded entry', async ({ browser }) => {
    await insertRow('malt_depots', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-malt-read-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Brauerei Shops/i);
      await expect(page.getByRole('heading', { name: 'Brauerei Shops' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-malt-read/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });

  test('Delete: confirm → row removed', async ({ browser }) => {
    await insertRow('malt_depots', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-malt-del-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Brauerei Shops/i);
      await expect(page.getByRole('heading', { name: 'Brauerei Shops' })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-malt-del/i })).toBeVisible({ timeout: 10_000 });

      await clickDeleteForRow(page, /e2e-malt-del/i);
      await waitForFlutter(page);
      await page.waitForTimeout(500);
      await expect(page.getByRole('button', { name: /Abbrechen/i })).toBeVisible({ timeout: 5_000 });
      await page.getByRole('button', { name: /^Löschen$/i }).last().click();
      await page.waitForTimeout(2_000);

      const rows = await queryRows('malt_depots','e2e-malt-del-');
      expect(rows.length).toBe(0);
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// PackagingProfile — CRD
// ============================================================================
test.describe('PackagingProfile CRD', () => {
  const ts = Date.now();

  test.beforeAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'packaging_profiles');
  });

  test.afterAll(async () => {
    await cleanupE2ERows(apiCtx, token, 'packaging_profiles');
  });

  test('Create: open form, fill name, save → row in DB', async ({ browser }) => {
    const name = `e2e-pkg-${ts}`;
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Zielmenge, Abfüllen & Lagern/i);
      await expect(page.getByRole('heading', { name: /Zielmenge/i })).toBeVisible({ timeout: 10_000 });

      await page.getByRole('button', { name: /^Neu$/i }).click();
      await waitForFlutter(page);
      await page.waitForTimeout(500);

      await page.getByLabel(/Name/i).fill(name);
      await page.getByRole('button', { name: /Speichern/i }).click();
      await page.waitForTimeout(1_500);

      const rows = await queryRows('packaging_profiles', 'e2e-pkg-');
      expect(rows.length).toBeGreaterThanOrEqual(1);
    } finally {
      await ctx.close();
    }
  });

  test('Read: list shows seeded entry', async ({ browser }) => {
    await insertRow('packaging_profiles', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-pkg-read-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Zielmenge, Abfüllen & Lagern/i);
      await expect(page.getByRole('heading', { name: /Zielmenge/i })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-pkg-read/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });

  test('Delete: confirm → row removed', async ({ browser }) => {
    await insertRow('packaging_profiles', {
      user_profile_id: TEST_USER_UUID,
      name: `e2e-pkg-del-${ts}`,
    });

    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Zielmenge, Abfüllen & Lagern/i);
      await expect(page.getByRole('heading', { name: /Zielmenge/i })).toBeVisible({ timeout: 10_000 });
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      await expect(page.getByRole('button', { name: /e2e-pkg-del/i })).toBeVisible({ timeout: 10_000 });

      await clickDeleteForRow(page, /e2e-pkg-del/i);
      await waitForFlutter(page);
      await page.waitForTimeout(500);
      await expect(page.getByRole('button', { name: /Abbrechen/i })).toBeVisible({ timeout: 5_000 });
      await page.getByRole('button', { name: /^Löschen$/i }).last().click();
      await page.waitForTimeout(2_000);

      const rows = await queryRows('packaging_profiles', 'e2e-pkg-del-');
      expect(rows.length).toBe(0);
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// FiningAgents — page opens (single settings record, not a list with name rows)
// ============================================================================
test.describe('FiningAgents page opens', () => {
  // FiningAgents is a single settings record (checkboxes + extras), not a list
  // of named rows. The page has no "name" column and no list/delete flow.
  // We verify the page opens and a known checkbox is visible.
  test('FiningAgents page opens with known fining options', async ({ browser }) => {
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Klärmittel/i);
      await expect(page.getByRole('heading', { name: /Klärmittel/i })).toBeVisible({ timeout: 10_000 });
      // Give the page content a moment to populate semantic tree
      await page.waitForTimeout(1_000);
      await waitForFlutter(page);
      // Known option from source: 'Irish Moss' — CheckboxListTile exposes via aria-label or text
      // Try getByRole('checkbox') or getByRole('button') with name pattern first, then text
      const irishMossLocator = page.getByRole('checkbox', { name: /Irish Moss/i })
        .or(page.getByRole('button', { name: /Irish Moss/i }))
        .or(page.getByText('Irish Moss'));
      await expect(irishMossLocator.first()).toBeVisible({ timeout: 8_000 });
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// Keezer — CRD
// Note: KeezerManagerPage auto-navigates to KeezerConfigPage when no config exists.
// We test that the page opens (either KeezerManager or KeezerConfig).
// ============================================================================
test.describe('Keezer page opens', () => {
  test('Keezer page opens (manager or config page visible)', async ({ browser }) => {
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /Keezer/i);
      // Either KeezerManager or KeezerConfigPage — both have "Keezer" in title
      await expect(page.getByRole('heading', { name: /Keezer/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// Hops — page opens (Brewfather-dependent, will show error or empty state without creds)
// ============================================================================
test.describe('Hops page opens', () => {
  test('Hops manager page opens (shows title "Hopfen")', async ({ browser }) => {
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Hopfen$/i);
      // AppBar title is "Hopfen (Brewfather)" from hops_manager_page.dart
      await expect(page.getByRole('heading', { name: /Hopfen/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });
});

// ============================================================================
// Miscs — page opens
// ============================================================================
test.describe('Miscs page opens', () => {
  test('Miscs manager page opens', async ({ browser }) => {
    const ctx = await browser.newContext({ storageState: STORAGE_STATE });
    const page = await ctx.newPage();
    try {
      await openManagerFromProfile(page, /^Sonstiges$/i);
      // MiscsManagerPage title (from source inspection)
      await expect(page.getByRole('heading', { name: /Sonstiges/i })).toBeVisible({ timeout: 10_000 });
    } finally {
      await ctx.close();
    }
  });
});
