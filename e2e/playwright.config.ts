import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',

  // Global timeout for each test
  timeout: 60_000,

  // Expect timeout — Flutter cold-start can be slow
  expect: {
    timeout: 15_000,
    toHaveScreenshot: {
      maxDiffPixels: 100,
      threshold: 0.2,
    },
  },

  // Collect all failures before stopping.
  // workers=1: prevents premature afterAll firing for serial describe groups.
  // With fullyParallel=false and workers>1, Playwright batches N tests per worker
  // even in serial mode, which causes afterAll to fire mid-suite (Playwright limitation).
  // The suite is small (< 100 tests) and Flutter-bound (~2–15 s/test), so 1 worker
  // is fast enough (< 2 min total).
  fullyParallel: false,
  workers: 1,

  // Retries: none for TDD clarity — flaky tests must be fixed, not retried
  retries: 0,

  reporter: [['list'], ['html', { open: 'never' }]],

  use: {
    // App base URL — default to 8081 (actual mapped port)
    baseURL: process.env.BASE_URL ?? 'http://localhost:8081',

    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',

    // Give Flutter's CanvasKit time to boot
    navigationTimeout: 30_000,
  },

  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1280, height: 800 },
        // StorageState is injected per-test via fixture when auth is needed;
        // global-setup writes it for reuse
      },
    },
  ],

  globalSetup: './global-setup.ts',

  // No webServer — we do NOT auto-start; the docker stack is the runtime
  webServer: undefined,
});
