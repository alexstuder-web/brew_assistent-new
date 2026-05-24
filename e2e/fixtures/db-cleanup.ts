import { APIRequestContext } from '@playwright/test';

const SUPABASE_URL = process.env.SUPABASE_URL ?? 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? '';

export const TEST_USER_UUID = 'f939286f-924c-4862-8800-f63d7f65b265';

/**
 * Deletes rows in the given aibrewgenius table that were created by the test user
 * and whose name column starts with "e2e-".
 *
 * Uses the User JWT so RLS is applied — no service_role keys in tests.
 *
 * @param requestContext - Playwright APIRequestContext (from `request` fixture)
 * @param accessToken    - User JWT obtained via apiLogin()
 * @param table          - Table name inside the aibrewgenius schema (e.g. "water_profiles")
 */
export async function cleanupE2ERows(
  requestContext: APIRequestContext,
  accessToken: string,
  table: string,
): Promise<void> {
  const url = `${SUPABASE_URL}/rest/v1/${table}?name=like.e2e-%`;
  const res = await requestContext.delete(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
  });

  if (!res.ok()) {
    const body = await res.text();
    console.warn(`[db-cleanup] DELETE ${table} returned ${res.status()}: ${body}`);
  }
}

/**
 * Deletes rows in ai_generated_recipes_v2 owned by the test user with name like "e2e-%".
 */
export async function cleanupE2ERecipes(
  requestContext: APIRequestContext,
  accessToken: string,
): Promise<void> {
  await cleanupE2ERows(requestContext, accessToken, 'ai_generated_recipes_v2');
}

// ---------------------------------------------------------------------------
// Vault-slot backup/restore helpers (for Integrations Suite)
// ---------------------------------------------------------------------------

/**
 * Reads back the current Brewfather creds via RPC.
 * Returns null if not set.
 */
export async function snapshotBrewfatherCreds(
  requestContext: APIRequestContext,
  accessToken: string,
): Promise<{ user_id: string; api_key: string } | null> {
  const url = `${SUPABASE_URL}/rest/v1/rpc/get_my_brewfather_creds`;
  const res = await requestContext.post(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    data: {},
  });
  const rows = await res.json();
  if (!Array.isArray(rows) || rows.length === 0) return null;
  return rows[0] as { user_id: string; api_key: string };
}

/**
 * Reads back the current RAPT creds via RPC.
 * Returns null if not set.
 */
export async function snapshotRaptCreds(
  requestContext: APIRequestContext,
  accessToken: string,
): Promise<{ user_id: string; api_key: string } | null> {
  const url = `${SUPABASE_URL}/rest/v1/rpc/get_my_rapt_creds`;
  const res = await requestContext.post(url, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    data: {},
  });
  const rows = await res.json();
  if (!Array.isArray(rows) || rows.length === 0) return null;
  return rows[0] as { user_id: string; api_key: string };
}

// NOTE: Full vault-restore (set_my_*_creds with saved values) is implemented
// in integrations.spec.ts where the backup/restore lifecycle is managed.
