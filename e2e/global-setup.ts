import { chromium, request } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const BASE_URL = process.env.BASE_URL ?? 'http://localhost:8081';
const SUPABASE_URL = process.env.SUPABASE_URL ?? 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? '';
const TEST_EMAIL = process.env.TEST_EMAIL ?? 'alex@alexstuder.ch';
const TEST_PASSWORD = process.env.TEST_PASSWORD ?? 'asdf';
const AUTH_DIR = path.join(__dirname, '.auth');
const STORAGE_STATE_FILE = path.join(AUTH_DIR, 'user.json');

async function globalSetup() {
  // Ensure .auth directory exists
  fs.mkdirSync(AUTH_DIR, { recursive: true });

  // 1. Obtain a Supabase JWT via REST (fast, no browser needed)
  const apiCtx = await request.newContext();
  const tokenRes = await apiCtx.post(
    `${SUPABASE_URL}/auth/v1/token?grant_type=password`,
    {
      headers: {
        apikey: SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
      data: {
        email: TEST_EMAIL,
        password: TEST_PASSWORD,
      },
    },
  );

  if (!tokenRes.ok()) {
    const body = await tokenRes.text();
    throw new Error(
      `global-setup: Supabase auth failed (${tokenRes.status()}): ${body}\n` +
        `Check TEST_EMAIL/TEST_PASSWORD and SUPABASE_ANON_KEY.`,
    );
  }

  const { access_token, refresh_token, expires_in, expires_at, user } =
    await tokenRes.json();

  console.log(
    `[global-setup] Authenticated as ${user.email} (uid=${user.id})`,
  );

  // 2. Build a storageState that contains the Supabase session in localStorage.
  //    Flutter's Supabase SDK stores the session under the key
  //    "sb-<projectRef>-auth-token". Since we are talking to local Supabase,
  //    we synthesise a minimal storageState so Flutter's AuthGate sees a valid
  //    session on startup — bypassing the AuthPage for all non-auth tests.
  const sessionValue = JSON.stringify({
    access_token,
    refresh_token,
    expires_in,
    expires_at,
    token_type: 'bearer',
    user,
  });

  // The storage key used by supabase-js v2 / supabase_flutter when talking to
  // a local instance. The project ref is derived from the URL.
  // For local dev the key is typically "sb-localhost-auth-token" but the exact
  // pattern is "sb-<hostname>-auth-token". We write both common variants.
  const storageState = {
    cookies: [],
    origins: [
      {
        origin: BASE_URL,
        localStorage: [
          {
            name: 'sb-localhost-auth-token',
            value: sessionValue,
          },
          {
            // Alternate form used by some supabase_flutter versions
            name: 'sb-127.0.0.1-auth-token',
            value: sessionValue,
          },
        ],
      },
    ],
  };

  fs.writeFileSync(STORAGE_STATE_FILE, JSON.stringify(storageState, null, 2));
  console.log(`[global-setup] storageState written to ${STORAGE_STATE_FILE}`);

  await apiCtx.dispose();
}

export default globalSetup;
