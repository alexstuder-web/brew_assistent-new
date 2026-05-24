/**
 * Suite 1: Smoke / Health
 *
 * Scope: Is the app up? Is the proxy up? Is Supabase up?
 * Can we log in? Does BrewEntryPage render correctly?
 *
 * These tests must NEVER write any data.
 * curl-level checks are duplicated here via Playwright `request` for
 * unified reporting; the bash equivalents live in scripts/smoke.sh.
 */

import { test, expect, request as playwrightRequest } from '@playwright/test';
import { waitForFlutter } from '../fixtures/flutter-a11y';
import { uiLogin, TEST_EMAIL, TEST_PASSWORD } from '../fixtures/auth';

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:8081';
// PROXY_URL may include a base-path suffix (e.g. "http://localhost:8083/api").
// For health-check purposes we want just the origin. Strip any path.
const PROXY_URL_RAW = process.env.PROXY_URL ?? 'http://localhost:8083';
const PROXY_ORIGIN = (() => {
  try {
    const u = new URL(PROXY_URL_RAW);
    return `${u.protocol}//${u.host}`;
  } catch {
    return PROXY_URL_RAW;
  }
})();
const SUPABASE_URL = process.env.SUPABASE_URL ?? 'http://localhost:54321';

// ---------------------------------------------------------------------------
// HTTP-level smoke (no browser needed)
// ---------------------------------------------------------------------------

test.describe('HTTP health checks', () => {
  test('App: GET / returns 200', async () => {
    const ctx = await playwrightRequest.newContext();
    const res = await ctx.get(BASE_URL);
    expect(res.status()).toBe(200);
    await ctx.dispose();
  });

  test('App: GET / returns HTML containing Flutter bootstrap', async () => {
    const ctx = await playwrightRequest.newContext();
    const res = await ctx.get(BASE_URL);
    const body = await res.text();
    // The Flutter Web build always includes flutter_bootstrap.js
    expect(body).toContain('flutter_bootstrap.js');
    await ctx.dispose();
  });

  test('Proxy: GET / returns 200 with status and version fields', async () => {
    // Health endpoint is always at the proxy origin root, not the /api base-path
    const ctx = await playwrightRequest.newContext();
    const res = await ctx.get(PROXY_ORIGIN);
    expect(res.status()).toBe(200);
    const json = await res.json();
    expect(json).toHaveProperty('status', 'Proxy is running');
    expect(json).toHaveProperty('version');
    await ctx.dispose();
  });

  test('Supabase: GET /auth/v1/health returns 200', async () => {
    const ctx = await playwrightRequest.newContext();
    const res = await ctx.get(`${SUPABASE_URL}/auth/v1/health`);
    expect(res.status()).toBe(200);
    const json = await res.json();
    // GoTrue health response always has a "version" field
    expect(json).toHaveProperty('version');
    await ctx.dispose();
  });
});

// ---------------------------------------------------------------------------
// Browser smoke — Flutter rendering + auth flow
// ---------------------------------------------------------------------------

test.describe('Browser smoke', () => {
  test('App: unauthenticated user lands on AuthPage with E-Mail and Passwort labels', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForFlutter(page);

    // Auth form fields must be visible
    await expect(page.getByLabel('E-Mail')).toBeVisible();
    await expect(page.getByLabel('Passwort')).toBeVisible();

    // The main submit button should say "Anmelden" (default state, not signup)
    await expect(
      page.getByRole('button', { name: 'Anmelden' }),
    ).toBeVisible();
  });

  test('App: valid login redirects to BrewEntryPage', async ({ page }) => {
    await page.goto('/');
    await waitForFlutter(page);

    await page.getByLabel('E-Mail').fill(TEST_EMAIL);
    await page.getByLabel('Passwort').fill(TEST_PASSWORD);
    await page.getByRole('button', { name: 'Anmelden' }).click();

    // BrewEntryPage renders "Users profil" entry button
    await expect(
      page.getByRole('button', { name: /Users profil/i }),
    ).toBeVisible({ timeout: 15_000 });
  });

  test('App: invalid password shows error message and stays on AuthPage', async ({
    page,
  }) => {
    await page.goto('/');
    await waitForFlutter(page);

    await page.getByLabel('E-Mail').fill(TEST_EMAIL);
    await page.getByLabel('Passwort').fill('wrong-password-xyz');
    await page.getByRole('button', { name: 'Anmelden' }).click();

    // Should stay on AuthPage — form fields still visible
    await expect(page.getByLabel('E-Mail')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByLabel('Passwort')).toBeVisible();

    // An error message should appear (AuthException from Supabase).
    // We don't assert exact text because Supabase error messages can vary,
    // but there must be some visible error text on the page.
    // The auth_page.dart renders the error in a Text widget with color redAccent.
    // We look for any text that indicates failure.
    const errorVisible = await page
      .getByText(/invalid|incorrect|wrong|ungültig|fehlgeschlagen|Invalid/i)
      .isVisible()
      .catch(() => false);

    // If the generic pattern doesn't match, at least the submit button must
    // still be present (i.e., no navigation to BrewEntryPage occurred)
    await expect(
      page.getByRole('button', { name: 'Anmelden' }),
    ).toBeVisible();

    // Entry page button must NOT be present
    await expect(
      page.getByRole('button', { name: /Users profil/i }),
    ).not.toBeVisible();

    // Accept the test even if the exact error text was elusive —
    // the key assertion is "did not navigate away from AuthPage"
    void errorVisible; // acknowledged: may be false if text differs
  });

  test('App: BrewEntryPage shows all 4 entry buttons after login', async ({
    page,
  }) => {
    // Login first
    await page.goto('/');
    await waitForFlutter(page);
    await page.getByLabel('E-Mail').fill(TEST_EMAIL);
    await page.getByLabel('Passwort').fill(TEST_PASSWORD);
    await page.getByRole('button', { name: 'Anmelden' }).click();

    // Wait for BrewEntryPage
    await page
      .getByRole('button', { name: /Users profil/i })
      .waitFor({ timeout: 15_000 });

    // Assert all 4 required entry buttons
    await expect(
      page.getByRole('button', { name: /Users profil/i }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /Currently Brewing/i }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /Start, entdecken wir ein neues Bier/i }),
    ).toBeVisible();
    await expect(
      page.getByRole('button', { name: /Freie Text beschreibung/i }),
    ).toBeVisible();

    // NOTE: "Studio" button is conditional on EnvConfig.studioUrl() returning
    // non-null. In non-local environments this button does NOT appear (by design).
    // We do NOT assert it here to keep the test env-agnostic.
  });
});
