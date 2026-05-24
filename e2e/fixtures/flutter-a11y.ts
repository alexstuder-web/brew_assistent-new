import { Page } from '@playwright/test';

/**
 * Wait for the Flutter glass-pane and force-enable the semantic tree.
 *
 * Flutter Web with CanvasKit renders to <canvas> — Playwright cannot use
 * getByText / getByRole until the semantic tree is enabled.
 *
 * Without this, getByText/getByRole on canvas-rendered widgets return nothing.
 * Must be called after every page.goto().
 */
export async function waitForFlutter(page: Page): Promise<void> {
  // Wait for the Flutter glass pane to mount (the CanvasKit root element).
  // Use state:'attached' — Flutter sets CSS visibility:hidden on flt-glass-pane
  // itself (the canvas sits below it); Playwright's default 'visible' state would
  // time out waiting for an element that is intentionally CSS-hidden.
  await page.waitForSelector('flt-glass-pane', { state: 'attached', timeout: 30_000 });

  // Enable the Flutter accessibility / semantic tree.
  // Flutter injects a hidden button "Enable accessibility" on first render.
  // We click it programmatically to avoid the pointer-event restriction.
  await page.evaluate(() => {
    const sel = '[aria-label="Enable accessibility"]';
    const btn = document.querySelector(sel) as HTMLElement | null;
    if (btn) {
      btn.click();
    }
  });

  // Give the semantic tree a tick to populate
  await page.waitForTimeout(500);
}
