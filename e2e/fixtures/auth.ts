import { test as base, request as baseRequest, Page, APIRequestContext } from '@playwright/test';
import { waitForFlutter } from './flutter-a11y';
import * as path from 'path';

export const TEST_EMAIL = process.env.TEST_EMAIL ?? 'alex@alexstuder.ch';
export const TEST_PASSWORD = process.env.TEST_PASSWORD ?? 'asdf';

export const STORAGE_STATE = path.join(__dirname, '..', '.auth', 'user.json');

/**
 * Performs a full UI login through the AuthPage form.
 * Use sparingly — prefer storageState via the authedPage fixture.
 * Use this for auth-specific tests that need to exercise the form itself.
 */
export async function uiLogin(page: Page): Promise<void> {
  await page.goto('/');
  await waitForFlutter(page);

  await page.getByLabel('E-Mail').fill(TEST_EMAIL);
  await page.getByLabel('Passwort').fill(TEST_PASSWORD);
  await page.getByRole('button', { name: /Anmelden/ }).click();

  // Wait for BrewEntryPage to confirm successful login
  await page.getByRole('button', { name: /Users profil/i }).waitFor({ timeout: 15_000 });
}

/**
 * Obtains a Supabase JWT access_token via REST (no browser needed).
 * Returns the raw access_token string.
 */
export async function apiLogin(
  requestContext: APIRequestContext,
): Promise<string> {
  const supabaseUrl = process.env.SUPABASE_URL ?? 'http://localhost:54321';
  const anonKey = process.env.SUPABASE_ANON_KEY ?? '';

  const res = await requestContext.post(
    `${supabaseUrl}/auth/v1/token?grant_type=password`,
    {
      headers: {
        apikey: anonKey,
        'Content-Type': 'application/json',
      },
      data: {
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
      },
    },
  );

  if (!res.ok()) {
    const body = await res.text();
    throw new Error(`apiLogin failed (${res.status()}): ${body}`);
  }

  const json = await res.json();
  return json.access_token as string;
}

// ---------------------------------------------------------------------------
// Custom fixture: authedPage
// Returns a Page that is already authenticated via a cached storageState.
// This avoids a UI login round-trip for every test.
// ---------------------------------------------------------------------------
export const test = base.extend<{ authedPage: Page }>({
  authedPage: async ({ browser }, use) => {
    const ctx = await browser.newContext({
      storageState: STORAGE_STATE,
    });
    const page = await ctx.newPage();
    await use(page);
    await ctx.close();
  },
});

export { expect } from '@playwright/test';
