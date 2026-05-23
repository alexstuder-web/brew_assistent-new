# Test Plan — brew_assistent

Status: Plan only (no test code yet). Source of truth for test scope, suites and coverage targets. To be implemented by `flutter-tester` against this plan.

---

## Coverage-Ziel und -Metrik

### Was "≥80% Coverage" hier konkret heißt

Nicht Dart-Code-Coverage (irrelevant für eine E2E-Suite, die CanvasKit-rendered Flutter Web treibt). Stattdessen vier Surface-Metriken, gewichtet aggregiert:

| Metrik | Definition | Gewicht |
|---|---|---|
| **Page-Coverage** | Erreichbare Page-Klassen in `lib/pages/`, die in mindestens einem Test geöffnet + auf ein erwartetes Marker-Widget assertet werden | 30 % |
| **CRUD-Coverage** | Entitäten mit user-facing CRUD, bei denen Create + Read + Update + Delete getestet ist (1 Punkt pro Operation) | 25 % |
| **Service-Boundary-Coverage** | `*Service`-Klassen in `lib/services/`, die in einem Test entweder via UI oder über direkten Supabase-Client-Call exerciert werden | 20 % |
| **Proxy-Endpoint-Coverage** | `/api/*`-Routen in `brew-proxy-new/server.js`, je mit ≥1 positivem + ≥1 negativem (401/400) Test | 25 % |

Bonus-Metrik (nicht in Gewichtung, aber gemessen):
- **Auth-State-Coverage** — jede geschützte Page einmal als anonymous getestet (Redirect zu AuthPage)
- **Vault-Coverage** — Brewfather + RAPT je set/get-via-proxy/configured-flag/delete

### Aktuelle App-Surface in Zahlen

Gezählt aus `lib/pages/`, `lib/services/`, `brew-proxy-new/server.js`, `db_scripts/migrations/003_vault.sql`:

| Kategorie | Total | Anmerkung |
|---|---:|---|
| Pages (`.dart` in `lib/pages/`) | 45 | inkl. 5 named routes (`/`, `/auth`, `/user-profile`, `/discover`, `/prompt`) — Rest via `MaterialPageRoute` push |
| Services (`*_service.dart`) | 18 | siehe Liste in Suite-Mapping |
| Proxy-Endpunkte (`/api/*`) | 13 | siehe Liste in Suite 10 |
| CRUD-Entitäten (user-facing) | 9 | WaterProfiles, BrewKettles, Fermenters, FermenterControllers, MaltDepots, PackagingProfiles, FiningAgents, YeastBank, Hops/Miscs (zusammen) |
| Named routes (main.dart) | 4 (+1 AuthGate-gerendert) | `/`, `/user-profile`, `/discover`, `/prompt`; `/auth` wird in main.dart NICHT registriert, sondern von `AuthGate` direkt instanziiert (siehe Follow-up #1) |
| RPC-Funktionen (Vault) | 4 | `get_my_brewfather_creds`, `get_my_rapt_creds`, `set_my_brewfather_creds`, `set_my_rapt_creds` |

### Geplante Coverage pro Kategorie

| Metrik | Tests treffen | Total | Coverage | Begründung |
|---|---:|---:|---:|---|
| Pages | 38 | 45 | **84 %** | Ausgeschlossen: `legacy_recipe_pages.dart` (deprecated), `yeast_label_page.dart` (reines Druck-Layout), `json_export_page.dart` (Read-only Side-Effekt), `fine_tuning_*` (4 Pages — nur visuelles Snapshot, kein Functional, da deep behind chained dialogs), `keezer_config_page.dart` (sub-page von keezer_manager — wird über CRUD-Test implizit erreicht aber nicht eigenständig validiert) |
| CRUD-Entitäten | 9 von 9 | 9 | **100 %** | Smoke (Create + List + Delete) für alle 9; Update für 4 repräsentative (WaterProfile, BrewKettle, Fermenter, YeastBank) |
| Services | 16 | 18 | **89 %** | `OpenAIService` (kostet → mocked) und `CalendarService` (rein client-seitig, kein Backend) sind über Mocks/skipped getestet; alle Backend-Services über CRUD- + Read-Tests |
| Proxy-Endpunkte | 13 von 13 | 13 | **100 %** | jeder Endpunkt mind. 1 Auth-Fail-Test; 11 von 13 zusätzlich mit positivem JWT-Test (OpenAI-Endpunkte `/api/brew`, `/api/chat`, `/api/picture` nur als 400 "missing prompt" + Status-200-stubbed, kein echter OpenAI-Call) |

**Aggregierte gewichtete Coverage: 0.30·0.84 + 0.25·1.00 + 0.20·0.89 + 0.25·1.00 = 0.252 + 0.250 + 0.178 + 0.250 = 0.93 → ≈ 93 %.**

Damit komfortabel über dem 80 %-Ziel. Puffer eingeplant für realistische Skips (Brewfather-Writes ohne Sandbox-Account, RAPT mit `invalid_grant`-Key) — selbst wenn beide Suiten teilweise gerinnen, bleibt der Wert über 80 %.

---

## Test-Stack-Anwendung

### Werkzeug-Aufteilung

| Aufgabe | Tool | Begründung |
|---|---|---|
| Page-Render, Klicks, Formulareingaben, Navigation | **Playwright Browser (Chromium)** | E2E gegen echten Flutter-Web-Build mit AuthGate, RLS-Kontext, Routing |
| Snapshot-Regression (5 Seiten) | **Playwright `toHaveScreenshot()`** | Catches CanvasKit-Rendering-Drift bei Theme- oder Layout-Änderungen |
| Direkte Proxy-API-Tests (Auth-Boundary, JSON-Schema) | **Playwright `request` Fixture** | Schneller als Browser, präzise Assertions, ohne CanvasKit-Overhead |
| Smoke (Proxy up? Supabase up? App-HTML lädt?) | **bash + curl in `e2e/scripts/smoke.sh`** | Lieferbar als CI-Health-Check ohne Node-Stack |
| Direkter Supabase-Auth-REST (Token holen für API-Tests) | **Playwright `request`** | Wie in Agent-Definition vorgegeben — Pattern: `/auth/v1/token?grant_type=password` |

### Mocking-Strategie

| Endpoint / Service | Strategie | Grund |
|---|---|---|
| `POST /api/brew`, `/api/chat`, `/api/picture` | **Negative only** (400 fehlender Prompt). Positiver Test ist optional und wird mit `test.skip(!process.env.RUN_OPENAI_TESTS)` versehen | OpenAI-Calls kosten und sind nicht-deterministisch |
| `POST /api/shop-search` | Negativ (400 missing query) + positiv mit `query=test` (Crawler ist deterministischer als OpenAI) | Crawler-Antwort ist HTML-scraping → 200 + JSON-Schema reicht |
| Brewfather READ (Recipes/Batches/Inventory) | **Real-Calls erlaubt** (read-only gegen `https://api.brewfather.app/v2`) | API ist stabil, idempotent, kein Risiko für User-Daten |
| Brewfather WRITE (Sync Batch upload) | **Skip** oder gegen Sandbox-Account (nicht im Plan) | Mutation gegen Prod-Konto verboten (Agent-Definition) |
| RAPT `/api/rapt/*` | Real-Call wenn `RAPT_TEST_OK=1`, sonst `test.skip` mit Begründung | Bekannter `invalid_grant`-Status für gespeicherten Key (project_auth_migration) |
| Supabase RPC (`set_my_*_creds`, `get_my_*_creds`) | **Real-Calls gegen lokales Supabase** | Vault-Roundtrip ist Kern-Sicherheits-Property, MUSS echt getestet werden |

### Test-User-Setup

Wie in `project_auth_migration.md` definiert: Bootstrap-User `alex@alexstuder.ch` / `asdf` ist bereits in `auth.users` + `auth.identities` durch `002_auth.sql` angelegt. Trigger `handle_new_user()` erzeugt automatisch eine `user_profiles`-Row mit derselben UUID.

**Fixtures bauen darauf auf:**

1. **Global Setup** (`e2e/global-setup.ts`): einmal pro Suite-Run via Playwright `request` ein Supabase-Token holen → `e2e/.auth/user.json` (storageState) cachen. Zweck: nicht für jeden Test durch die UI-Login-Maske; speedup ~5s pro Test.
2. **Per-Test Cleanup** (`e2e/fixtures/db-cleanup.ts`): Vor CRUD-Tests, die Daten schreiben (WaterProfile, BrewKettle, ...), wird eine `DELETE FROM aibrewgenius.<table> WHERE user_profile_id = '<test-uuid>' AND name LIKE 'e2e-%'` gefeuert. Direkt via Supabase REST mit User-JWT, RLS-konform. Keine service_role-Keys in Tests.
3. **Vault-Cleanup**: nach Integrations-Suite `set_my_brewfather_creds(NULL)` und `set_my_rapt_creds(NULL)` aufrufen, damit der nächste Lauf von "configured = false" startet. **Achtung:** Suite muss bestehende Keys vorher sichern und am Ende zurückschreiben — sonst zerstört CI das Setup für Manual-QA.
4. **Auth-Helpers** (`e2e/fixtures/auth.ts`): `uiLogin(page)` (UI-Pfad für AuthPage-Tests), `apiLogin(request)` (REST-Pfad für API-Suiten).
5. **Flutter-A11y-Helper** (`e2e/fixtures/flutter-a11y.ts`): MUSS in jedem Browser-Test nach `page.goto()` aufgerufen werden, sonst findet Playwright keine canvas-rendered Widgets. Siehe Agent-Definition `flutter-tester.md`.

### Env-Variablen (aus `e2e/run.sh` exportiert)

| Variable | Default | Quelle |
|---|---|---|
| `BASE_URL` | `http://localhost:8084` | Argument oder `.env` |
| `PROXY_URL` | `http://localhost:8083` | `.env` |
| `SUPABASE_URL` | `http://localhost:54321` | `.env` |
| `SUPABASE_ANON_KEY` | aus `brew_assistent-new/.env` | `grep`-extrahiert |
| `TEST_EMAIL` | `alex@alexstuder.ch` | hardcoded fallback |
| `TEST_PASSWORD` | `asdf` | hardcoded fallback |
| `RUN_OPENAI_TESTS` | unset | `1` aktiviert kostenpflichtige Tests |
| `RAPT_TEST_OK` | unset | `1` aktiviert RAPT-Tests, sonst skip |
| `BREWFATHER_TEST_OK` | unset | `1` aktiviert Brewfather-Tests, sonst skip |

---

## Test-Suiten

### 1. Smoke / Health

- **Datei:** `tests/smoke.spec.ts` + `scripts/smoke.sh`
- **Scope:** App ist erreichbar, Proxy ist erreichbar, Supabase ist erreichbar, Auth-Flow grundsätzlich funktional
- **Tests:**
  - `App: GET / returns 200 and contains <flutter-glass-pane>` (curl)
  - `Proxy: GET / returns 200 with version field` (curl)
  - `Supabase: GET /auth/v1/health returns 200` (curl)
  - `App: unauthenticated user lands on AuthPage with "E-Mail" + "Passwort" labels`
  - `App: valid login redirects to BrewEntryPage (asserts "Users profil" button visible)`
  - `App: invalid password shows error message, stays on AuthPage`
  - `App: BrewEntryPage shows all 4 entry buttons (Users profil, Currently Brewing, Start entdecken, Freie Text)`
- **Setup:** keine. Smoke darf nichts schreiben.
- **Aufwand:** S (1h)
- **Priorität:** P0

### 2. Auth

- **Datei:** `tests/auth.spec.ts`
- **Scope:** Login, Logout, Signup-UI, Session-Persistence, Toggle Anmelden↔Registrieren
- **Tests:**
  - `valid credentials log user in`
  - `wrong password shows AuthException-Message, stays on AuthPage`
  - `empty email validator triggers "E-Mail erforderlich"`
  - `email without @ triggers "Ungültige E-Mail"`
  - `empty password triggers "Passwort erforderlich"`
  - `toggle button switches between "Anmelden" and "Registrieren" UI states`
  - `signup form posts to /auth/v1/signup` (intercept request, assert payload — keinen echten neuen User anlegen)
  - `logout via icon button returns to AuthPage`
  - `session persists across page reload (storageState round-trip)`
  - `expired/invalid JWT redirects to AuthPage` (manipuliere localStorage)
- **Setup:** keine geschriebenen Daten
- **Aufwand:** M (2h)
- **Priorität:** P0

### 3. User-Profile

- **Datei:** `tests/profile.spec.ts`
- **Scope:** `/user-profile` Page-Felder, Name + Language Update, Avatar Upload, Locale-Switch wirkt im UI
- **Tests:**
  - `profile page loads existing name from DB`
  - `change name and save persists to user_profiles` (RPC + reload assertion)
  - `language dropdown shows de + en, default = de`
  - `change language to en updates UI labels` (assert one known en-Label appears, z.B. "Water profiles" statt "Wasserprofile")
  - `change language to de restores German labels`
  - `avatar upload writes base64 blob to user_profiles.avatar_blob` (mock file input; assert API call)
  - `default batch liters input accepts only numeric, persists value`
  - `unsaved-changes warning is shown on back-navigation if name changed` (optional, abhängig vom Feature)
- **Setup:** Snapshot des originalen profile-Rows; restore am Ende
- **Aufwand:** M (2-3h)
- **Priorität:** P0

### 4. Integrations / Vault

- **Datei:** `tests/integrations.spec.ts`
- **Scope:** Brewfather + RAPT Credentials-Flow via Vault-RPC; UI-State-Mapping `configured`-Flag
- **Tests:**
  - `IntegrationsPage opens, both sections render`
  - `initial state: both chips show "Kein Key" if vault is empty`
  - `set Brewfather UserId + API-Key → save → reload → chip shows "Key gesetzt"`
  - `API-Key TextField is empty after save (not echoed back from server)` (Security-Property)
  - `chip "Key gesetzt" only appears after page reload (verify generated column brewfather_configured returns true)`
  - `click delete-icon next to Brewfather key → confirm dialog → key removed → chip "Kein Key"`
  - `same flow for RAPT (set, configured-flag, delete)`
  - `RPC: GET /rest/v1/rpc/get_my_brewfather_creds returns row with api_key when set` (direkter RPC-Call mit User-JWT)
  - `RPC: same call returns empty array when not set`
  - `RPC: GET /rest/v1/rpc/get_my_brewfather_creds without JWT → 401`
  - `Security: brewfather_api_key + rapt_api_key columns in user_profiles SELECT are always NULL` (post-003_vault.sql invariant — assert via `from(user_profiles).select('brewfather_api_key')`)
- **Setup:** Test-User existiert, beide Vault-Slots werden vor Suite-Run geleert + nach Suite-Run wiederhergestellt
- **Aufwand:** M (3h)
- **Priorität:** P0 (Sicherheits-kritisch)

### 5. Equipment-CRUD

- **Datei:** `tests/equipment.spec.ts`
- **Scope:** Alle 9 Entitäten mit user-facing Verwaltung — pro Entität mindestens Create + List + Delete (Smoke-CRUD); für 4 repräsentative auch Update.
- **Tests** (jeweils unter `test.describe('<Entity>', …)` gruppiert):
  - **WaterProfile** (volle CRUD): create with name `e2e-water-${ts}`, assert list shows entry, edit pH-Wert, delete, assert removed
  - **BrewKettle** (volle CRUD): create, edit volume, delete
  - **Fermenter** (volle CRUD): create, edit capacity, delete
  - **YeastBank** (volle CRUD): create yeast entry, edit viability, delete
  - **FermenterController** (CRD): create, list, delete (Edit ist UI-trivial — skip)
  - **MaltDepot** (CRD): create depot with one malt entry, list, delete
  - **PackagingProfile** (CRD): create, list, delete
  - **FiningAgents** (CRD): create, list, delete
  - **Hops** (CRD): create hops entry, list, delete
  - **Miscs** (CRD): create misc entry, list, delete
  - **Keezer** (CRD): create config, list, delete
  - `each list page renders empty-state correctly if user has no rows`
  - `each create-form validates required fields (name nicht-leer)`
- **Setup:** vor jedem Test ein cleanup-script, das alle Rows `WHERE user_profile_id=<test> AND name LIKE 'e2e-%'` löscht. Damit sind Tests idempotent und parallel-safe.
- **Aufwand:** L (5-6h)
- **Priorität:** P1

### 6. Recipe-Generation (Discovery + Free-Prompt)

- **Datei:** `tests/recipe-generation.spec.ts`
- **Scope:** Discovery-Welcome → Beer-Type → FineTuning-Chain → Result + Save. Plus Free-Prompt-Pfad. OpenAI-Calls werden **mocked** (Playwright `page.route('/api/brew', …)` interceptet und liefert fixturen-Antwort).
- **Tests:**
  - `Discovery: select "Pale Ale" → confirm dialog → FineTuningGeneralPage opens`
  - `Discovery: cancel dialog → no navigation`
  - `FineTuningGeneral → MainTrunk → Taste → Aftertaste flow reaches Completion page` (mocked OpenAI per step)
  - `RecipePromptPage: empty prompt → submit → "Prompt is required"-Error`
  - `RecipePromptPage: with prompt → mocked /api/brew returns recipe JSON → RecipeResultPage rendered`
  - `RecipeResultPage: "Speichern"-Button → recipe persisted in ai_generated_recipes_v2 (assert via direct REST select)`
  - `RecipeResultPage: "Verfeinern"/Iterate-Button (if exists) → re-submit with refinement`
  - `Save flow: saved recipe appears in GeneratedRecipesListPage`
  - `(optional, RUN_OPENAI_TESTS=1) full Discovery→Result with real OpenAI call — only smoke that recipe field is non-empty`
- **Setup:** Mock-Recipe JSON in `e2e/fixtures/mocks/recipe-pale-ale.json`. Test-User-Cleanup für `ai_generated_recipes_v2` am Ende.
- **Aufwand:** L (4-5h, FineTuning-Chain hat viele Bildschirme)
- **Priorität:** P1

### 7. Recipe-Browsing

- **Datei:** `tests/recipes.spec.ts`
- **Scope:** Generierte Rezepte listen + öffnen + Detail-Felder-Korrektheit
- **Tests:**
  - `GeneratedRecipesListPage shows seeded recipe rows (use fixture-prepared row inserted via REST)`
  - `Click row → RecipeDetailPage opens with all fields (Name, Style, ABV, IBU, Malts, Hops, Yeast)`
  - `RecipesListPage (non-AI recipes) lists rows from recipes table`
  - `Recipe detail: "Brauen starten"/Batch-Create-Button creates a batch entry`
  - `Empty list state: "Keine Rezepte"-Hint shown`
- **Setup:** vor Suite via REST 2-3 Test-Recipes inserten (`name LIKE 'e2e-%'`), am Ende löschen
- **Aufwand:** M (2h)
- **Priorität:** P1

### 8. Brewfather-Integration via Proxy

- **Datei:** `tests/brewfather.spec.ts`
- **Scope:** Brewfather-Menu, BrewfatherDataPage, READ-only API-Pfade über `/api/brewfather/*`. Schreibende Calls sind verboten (Agent-Boundary), werden geskippt.
- **Tests:**
  - `BrewfatherMenuPage opens, shows 3 entries (Recipes, Batches, Inventory)`
  - `(skip if !BREWFATHER_TEST_OK) GET /api/brewfather/recipes?limit=1 returns array`
  - `(skip if !BREWFATHER_TEST_OK) GET /api/brewfather/batches?limit=1 returns array`
  - `(skip if !BREWFATHER_TEST_OK) GET /api/brewfather/inventory/fermentables returns array`
  - `GET /api/brewfather/recipes without JWT → 401`
  - `GET /api/brewfather/recipes with JWT but no Brewfather creds in vault → 400 "Bitte im Profil eintragen"`
  - `BrewfatherDataPage renders fetched data (1 of 3 endpoints, e.g. recipes — mit Mock fallback)`
  - `Inventory sync UI flow: button click triggers GET to /api/brewfather/inventory and shows result count`
  - `Sync-write button is either disabled in test mode or skipped` (write-protect assertion)
- **Setup:** vor Suite muss Brewfather-Key in Vault sein (`BREWFATHER_TEST_OK=1` setzt Voraussetzung)
- **Aufwand:** M (3h)
- **Priorität:** P1

### 9. RAPT-Integration via Proxy

- **Datei:** `tests/rapt.spec.ts`
- **Scope:** RAPT-Token-Flow, Hydrometers, Telemetry. Bei `invalid_grant` (bekannter Stand) → graceful skip statt fail.
- **Tests:**
  - `GET /api/rapt/token without JWT → 401`
  - `GET /api/rapt/hydrometers without JWT → 401`
  - `(skip if !RAPT_TEST_OK) POST /api/rapt/token with JWT → returns access_token`
  - `(skip if !RAPT_TEST_OK) GET /api/rapt/hydrometers with JWT → returns array`
  - `(skip if !RAPT_TEST_OK) GET /api/rapt/telemetry with JWT → returns rows array`
  - `(skip if !RAPT_TEST_OK) GET /api/rapt/profiles with JWT → returns array`
  - `GET /api/rapt/telemetry/start-override returns persistedStartDate (GET)`
  - `POST /api/rapt/telemetry/start-override sets date, GET reflects it`
  - `DELETE /api/rapt/telemetry/start-override clears date`
  - `GET /api/rapt/telemetry with stored invalid_grant key → 4xx with parseable error message` (regression-guard für project_auth_migration#"RAPT-Key war beim Test invalid_grant")
- **Setup:** RAPT-Test-Key in Vault wenn `RAPT_TEST_OK=1`
- **Aufwand:** M (2-3h)
- **Priorität:** P1

### 10. Proxy-API direkt

- **Datei:** `tests/proxy.spec.ts`
- **Scope:** Jeder `/api/*` Endpoint einzeln — positiver + negativer Pfad, ohne UI. Komplett über Playwright `request`-Fixture.
- **Endpoints (vollständig aus `server.js` extrahiert):**
  | # | Endpoint | Method | Positiv-Test | Negativ-Test |
  |---|---|---|---|---|
  | 1 | `/` | GET | 200, `{status:'Proxy is running'}` | — |
  | 2 | `/api/brew` | POST | (skip OpenAI) | 400 missing prompt |
  | 3 | `/api/chat` | POST | (skip OpenAI) | 400 missing prompt |
  | 4 | `/api/picture` | POST | (skip OpenAI) | 400 missing prompt |
  | 5 | `/api/proxy-image?url=…` | GET | 200 + image content-type für reachable URL | 400 missing url |
  | 6 | `/api/shop-search` | POST | 200 + shops array | 400 missing query |
  | 7 | `/api/brewfather/<...>` | GET/POST | (siehe Suite 8) | 401 ohne JWT |
  | 8 | `/api/rapt/token` | POST | (siehe Suite 9) | 401 ohne JWT |
  | 9 | `/api/rapt/profiles` | GET | (siehe Suite 9) | 401 ohne JWT |
  | 10 | `/api/rapt/hydrometers` | GET | (siehe Suite 9) | 401 ohne JWT |
  | 11 | `/api/rapt/hydrometer-telemetry` | GET | (siehe Suite 9) | 400 missing params (auth-protected, get 401 first) |
  | 12 | `/api/rapt/telemetry` | GET | (siehe Suite 9) | 401 ohne JWT |
  | 13 | `/api/rapt/telemetry/start-override` | GET/POST/DELETE | siehe Suite 9 | 405 für andere Methoden, 400 für invalid date |
  | 14 | `/api/cache/telemetry` | GET | (skip if !RAPT_TEST_OK) | 401 ohne JWT |
  | 15 | `/api/cache/controllers` | GET | (skip if !RAPT_TEST_OK) | 401 ohne JWT |
- **Tests:** je 1 negative + 1 positive (where applicable, mit JWT) → 30 Tests total
- **Setup:** Token-Helper aus auth-fixture
- **Aufwand:** M (3h)
- **Priorität:** P0 (Auth-Boundary ist sicherheitskritisch)

### 11. Visual Regression

- **Datei:** `tests/visual/snapshot.spec.ts`
- **Scope:** Snapshot-Baselines für die 5 wichtigsten Seiten — fängt CanvasKit-Drifts bei Theme-Changes
- **Tests:**
  - `AuthPage @ 1280x800 — baseline`
  - `BrewEntryPage @ 1280x800 — baseline`
  - `UserProfilePage @ 1280x800 — baseline`
  - `IntegrationsPage @ 1280x800 — baseline`
  - `RecipeResultPage (with mocked recipe) @ 1280x800 — baseline`
- **Setup:** Tests laufen mit fixiertem `devices['Desktop Chrome']` + `maxDiffPixels: 100, threshold: 0.2` (aus Agent-Definition). Erste Run = Baseline-Generation, danach Diff-only.
- **Aufwand:** S (1-2h für Setup; Baselines selbst sind 1 Klick)
- **Priorität:** P2

### 12. i18n Sprach-Toggle (optional)

- **Datei:** `tests/i18n.spec.ts`
- **Scope:** Locale-Switch wirkt sofort auf eine Beispielseite ohne Reload
- **Tests:**
  - `UserProfilePage in de zeigt "Wasserprofile", switch → en → "Water profiles"`
  - `language preference in user_profiles.language persistiert über Logout/Login`
- **Aufwand:** S (1h)
- **Priorität:** P2

---

## Out-of-Scope (mit Grund)

| Bereich | Warum nicht getestet |
|---|---|
| **OpenAI-Endpoints `/api/brew`, `/api/chat`, `/api/picture` Happy-Path** | Kostet Geld pro Run, nicht-deterministisches Output. Stattdessen: mocked Responses + negative-only Tests. Opt-in via `RUN_OPENAI_TESTS=1`. |
| **Brewfather schreibender Calls (Sync Batch upload)** | Würde gegen User-Production-Konto schreiben. Verboten per Agent-Boundary. Erst mit Sandbox-Account. |
| **`fine_tuning_*_page.dart` Tiefen-Pfade (Taste, Aftertaste detail-Felder)** | Vier verkettete Pages mit ~15 Sliders/Dropdowns. ROI gering vs. Aufwand. Suite 6 testet nur Eintritt + Completion-Erreichen. |
| **`legacy_recipe_pages.dart`** | Klassen sind deprecated und nirgends mehr verlinkt (siehe Follow-up #2). |
| **`yeast_label_page.dart`, `json_export_page.dart`** | Reine Print/Export-Layouts, kein UI-State. |
| **Mobile/Tablet-Layouts** | App ist desktop-first; nur 1280×800 Viewport getestet. |
| **Firefox/WebKit** | Agent-Definition sagt nur Chromium. CanvasKit ist Browser-übergreifend identisch. |
| **Stress/Load** | Out-of-scope für Functional-Suite. Sollte `k6`/separate Suite werden. |
| **Real RAPT-Telemetry-Reconciliation gegen DB-Fallback** (`db-sync` Pfad) | Hängt an `dbSync.getPool()` + `rapt.*`-Schema, ist Background-Logik. Mehr eine Integration-Test-Domain als E2E. Wird per Smoke-Probe abgedeckt aber nicht im Detail. |
| **Watchtower / Docker Hub Auto-Deploy** | Infra-Concern, gehört nicht in App-E2E. |
| **`shopCrawler.js` Crawl-Korrektheit gegen echte Shops** | HTML der Shops ändert sich → flaky. Nur Smoke `200 + shops-array` getestet, nicht Schema/Inhalte. |

---

## Risiko-Areale (was Tests systematisch NICHT erwischen)

1. **CanvasKit-spezifische Render-Bugs (Anti-Aliasing, Font-Hinting auf bestimmten OS)** — Playwright sieht den DOM-Semantik-Tree, nicht Pixel-Korrektheit der Canvas-Rendering. Visual-Regression mit `maxDiffPixels: 100` würde subtile Glitches durchlassen. Mitigation: regelmäßig manuelle QA auf macOS + Windows + Linux.
2. **Race-Conditions zwischen Supabase realtime-Subscriptions und HTTP-Mutations** — Tests sind sequenziell, treffen das nicht.
3. **Externe API-Verfügbarkeit (Brewfather Down, RAPT-Token-Endpoint Down, OpenAI Down)** — Tests schlagen dann fehl, ohne dass die App falsch ist. Mitigation: Suiten 8 + 9 sind opt-in via Env-Flag, Smoke-Suite hat kein externes API-Dependency.
4. **Vault-Encryption-Bugs** (z.B. wenn Supabase die `pgsodium`-Library updatet) — Tests assertieren Roundtrip, aber nicht die Verschlüsselungs-Stärke. Sicherheits-Review notwendig (eigene Aufgabe von `flutter-reviewer`).
5. **Multi-User-RLS-Verletzungen** — wir testen nur mit einem User. Cross-Tenant-Test (User A sieht/ändert nicht User Bs Daten) ist offen — siehe Follow-up #3.
6. **Browser-Storage-Edge-Cases** — Cookies-Disabled, ITP-Cleanup, localStorage-Quotas. Storage-State wird einmalig gecached, dieser Pfad wird nicht abgedeckt.
7. **CSRF / CORS-Konfiguration in Production** — Tests laufen gegen lokales Setup mit liberalem CORS. Cloudflare-Tunnel-Verhalten weicht ab.
8. **Cloudflare-Tunnel-Latenz-bedingte Timeouts** — Remote-Run gegen `https://assistent.alexstuder.cloud` kann an `waitForFlutter`-Timeout (30s) scheitern, der lokal sicher passt.

---

## Coverage-Matrix

Spalten: **Suite #**, **Tests die treffen**, **Priorität**, **Status**. Status `planned` = noch nicht implementiert.

### Pages (45 total, 38 abgedeckt → 84 %)

| # | Page | Suite | Tests | Prio | Status |
|---|---|---|---:|---|---|
| 1 | `auth_page.dart` | 2, 11 | 10 | P0 | planned |
| 2 | `brew_entry_page.dart` | 1, 11 | 3 | P0 | planned |
| 3 | `discovery_welcome_page.dart` | 6 | 3 | P1 | planned |
| 4 | `recipe_prompt_page.dart` | 6 | 4 | P1 | planned |
| 5 | `user_profile_page.dart` | 3, 11 | 7 | P0 | planned |
| 6 | `integrations_page.dart` | 4, 11 | 11 | P0 | planned |
| 7 | `brewfather_menu_page.dart` | 8 | 1 | P1 | planned |
| 8 | `brewfather_data_page.dart` | 8 | 2 | P1 | planned |
| 9 | `water_profile_manager_page.dart` | 5 | 4 | P1 | planned |
| 10 | `water_profile_editor_page.dart` | 5 | 2 | P1 | planned |
| 11 | `brew_kettle_manager_page.dart` | 5 | 4 | P1 | planned |
| 12 | `fermenter_manager_page.dart` | 5 | 4 | P1 | planned |
| 13 | `fermenter_controller_manager_page.dart` | 5 | 3 | P1 | planned |
| 14 | `malt_depot_manager_page.dart` | 5 | 3 | P1 | planned |
| 15 | `packaging_profile_manager_page.dart` | 5 | 3 | P1 | planned |
| 16 | `fining_agents_page.dart` | 5 | 3 | P1 | planned |
| 17 | `yeast_bank_manager_page.dart` | 5 | 4 | P1 | planned |
| 18 | `yeast_bank_editor_page.dart` | 5 | 2 | P1 | planned |
| 19 | `hops_manager_page.dart` | 5 | 3 | P1 | planned |
| 20 | `miscs_manager_page.dart` | 5 | 3 | P1 | planned |
| 21 | `keezer_manager_page.dart` | 5 | 3 | P1 | planned |
| 22 | `keezer_config_page.dart` | (5 indirect) | 0 | P2 | excluded |
| 23 | `available_ingredients_page.dart` | 5 | 1 | P1 | planned |
| 24 | `recipes_list_page.dart` | 7 | 2 | P1 | planned |
| 25 | `recipe_detail_page.dart` | 7 | 1 | P1 | planned |
| 26 | `recipe_result_page.dart` | 6, 11 | 3 | P1 | planned |
| 27 | `recipe_summary_page.dart` | 6 | 1 | P1 | planned |
| 28 | `recipe_completion_page.dart` | 6 | 1 | P1 | planned |
| 29 | `generated_recipes_list_page.dart` | 6, 7 | 2 | P1 | planned |
| 30 | `batches_list_page.dart` | 7 | 1 | P1 | planned |
| 31 | `batch_detail_page.dart` | 7 | 1 | P1 | planned |
| 32 | `equipment_page.dart` | 5 | 1 | P2 | planned |
| 33 | `how_to_page.dart` | 5 | 1 | P2 | planned |
| 34 | `video_instructions_page.dart` | 5 | 1 | P2 | planned |
| 35 | `efficiency_calculator_page.dart` | 6 | 1 | P2 | planned |
| 36 | `special_additions_page.dart` | 6 | 1 | P2 | planned |
| 37 | `fine_tuning_general_page.dart` | 6 | 1 | P1 | planned |
| 38 | `fine_tuning_main_trunk_page.dart` | 6 | 0 | P2 | excluded |
| 39 | `fine_tuning_taste_page.dart` | 6 | 0 | P2 | excluded |
| 40 | `fine_tuning_aftertaste_page.dart` | 6 | 0 | P2 | excluded |
| 41 | `legacy_recipe_pages.dart` | — | 0 | — | excluded (deprecated) |
| 42 | `yeast_label_page.dart` | — | 0 | — | excluded (print-only) |
| 43 | `json_export_page.dart` | — | 0 | — | excluded (export-only) |
| 44 | `how_to/` (sub-dir) | 5 | 1 | P2 | planned |
| 45 | `batch_detail_tabs/` (sub-dir) | 7 | 1 | P1 | planned |

→ 38 abgedeckt / 45 total = **84 %**

### Services (18 total, 16 abgedeckt → 89 %)

| Service | Suite | Status |
|---|---|---|
| `user_profile_service.dart` | 3, 4 | planned |
| `water_profile_service.dart` | 5 | planned |
| `brew_kettle_service.dart` | 5 | planned |
| `fermenter_service.dart` | 5 | planned |
| `fermenter_controller_service.dart` | 5 | planned |
| `malt_depot_service.dart` | 5 | planned |
| `packaging_profile_service.dart` | 5 | planned |
| `fining_agents_service.dart` | 5 | planned |
| `yeast_bank_service.dart` | 5 | planned |
| `keezer_service.dart` | 5 | planned |
| `brewfather_service.dart` | 8 | planned |
| `brewfather_transformer_service.dart` | 8 (indirect) | planned |
| `rapt_service.dart` | 9 | planned |
| `ai_generated_recipes_service.dart` | 6, 7 | planned |
| `how_to_service.dart` | 5 | planned |
| `video_instruction_service.dart` | 5 | planned |
| `openai_service.dart` | 6 (mocked) | partial — keine echten OpenAI-Calls |
| `calendar_service.dart` | — | excluded — client-side only, kein Backend |

→ 16 / 18 = **89 %**

### Proxy-Endpunkte: 13 / 13 = **100 %** (siehe Tabelle in Suite 10)

### CRUD-Entitäten: 9 / 9 = **100 %** (siehe Suite 5)

---

## Vorgeschlagene Reihenfolge der Umsetzung

| Reihenfolge | Suite | Begründung |
|---:|---|---|
| 1 | **Setup** (playwright.config, fixtures, run.sh, .gitignore, global-setup mit storageState) | Ohne läuft kein Test |
| 2 | **Suite 1: Smoke** | P0, kürzeste Feedback-Loop, validiert ganzes Setup in 30s |
| 3 | **Suite 2: Auth** | P0, blockt sonst alle authenticated Tests |
| 4 | **Suite 10: Proxy-API** | P0, schnell (kein Browser nötig), validiert JWT-Boundary für alle weiteren Suiten |
| 5 | **Suite 4: Integrations/Vault** | P0 sicherheitskritisch, klärt ob `set_my_*_creds`-RPC funktioniert (Voraussetzung für Suite 8 + 9) |
| 6 | **Suite 3: User-Profile** | P0, kleine schnelle Suite |
| 7 | **Suite 5: Equipment-CRUD** | P1, größtes Surface aber Risiko/Aufwand am höchsten |
| 8 | **Suite 7: Recipe-Browsing** | P1, baut auf Recipes-Seed (kann ohne Generation-Suite vorgezogen werden mit REST-Seed) |
| 9 | **Suite 6: Recipe-Generation** | P1, am komplexesten wegen FineTuning-Chain + OpenAI-Mock |
| 10 | **Suite 8: Brewfather** | P1, opt-in (BREWFATHER_TEST_OK) |
| 11 | **Suite 9: RAPT** | P1, opt-in (RAPT_TEST_OK) |
| 12 | **Suite 11: Visual** | P2, am Ende — sobald Layout stabil ist |
| 13 | **Suite 12: i18n** | P2 |

Reasoning: Risk-Reduction-first (Auth, Boundary, Vault), dann Volume (CRUD), dann komplexer Flow (Recipe-Generation), dann opt-in External (Brewfather/RAPT), dann Polish (Visual + i18n).

---

## Geschätzter Gesamt-Aufwand

| Block | Stunden |
|---|---:|
| Setup (playwright.config + fixtures + global-setup + run.sh + .gitignore) | 3 |
| Suite 1 Smoke | 1 |
| Suite 2 Auth | 2 |
| Suite 3 User-Profile | 2.5 |
| Suite 4 Integrations/Vault | 3 |
| Suite 5 Equipment-CRUD | 5.5 |
| Suite 6 Recipe-Generation | 4.5 |
| Suite 7 Recipe-Browsing | 2 |
| Suite 8 Brewfather | 3 |
| Suite 9 RAPT | 2.5 |
| Suite 10 Proxy-API | 3 |
| Suite 11 Visual | 1.5 |
| Suite 12 i18n | 1 |
| **Gesamt** | **~34.5 h** |

Realistisch verteilt auf 1-2 Wochen für eine fokussierte Person.

### Erwartete Suite-Laufzeit

| Mode | Dauer |
|---|---|
| Lokal, alle Suiten, headless, parallel `workers: 4` | ~3 min |
| Lokal, alle Suiten, headed, serial | ~10 min |
| Remote (Cloudflare-Tunnel), alle Suiten, headless | ~6-8 min (Tunnel-Latenz + AuthGate cold-start) |
| Nur Suite 1 (Smoke) lokal | ~25 s |

---

## Follow-ups bei der Analyse aufgefallen

1. **AuthPage nicht in `main.dart`-Routes-Tabelle.** `BrewEntryPage`, `UserProfilePage`, `DiscoveryWelcomePage`, `RecipePromptPage` sind als named routes registriert. `AuthPage` wird ausschließlich von `widgets/auth_gate.dart` direkt instanziiert. Wenn jemand `/auth` per URL aufruft, knallt der Router. Test-relevant: Suite 2 muss `/auth`-URL → unauth → AuthPage-Rendering testen, nicht `pushNamed`.
2. **`legacy_recipe_pages.dart` existiert, ist aber nirgends referenziert.** Verdacht: dead code. Sollte gelöscht werden — eine Test-Suite würde es sonst künstlich abdecken müssen. Ausgeschlossen in Coverage-Matrix.
3. **Cross-Tenant-RLS-Test fehlt.** Wir haben einen Test-User. Für echte Multi-User-Sicherheit müsste ein zweiter User mit eigenem JWT versuchen, User-As-Daten zu sehen. Erfordert einen zweiten Bootstrap-User in DB. Wird im jetzigen Plan nicht abgedeckt — sollte eigener "RLS-Penetration-Test" sein, z.B. von `flutter-reviewer` mit `psql`-Direktzugriff.
4. **`/api/cache/telemetry` + `/api/cache/controllers` brauchen JWT** (siehe `requireRaptCreds` ganz oben in den Handlern), obwohl es Cache-Lese-Endpoints sind. Korrekt aus Sicherheits-Sicht, war aber nicht offensichtlich aus Endpoint-Naming — sollte im README/Doc des Proxy stehen.
5. **`handleRaptStartOverrideRequest` ohne Auth-Check.** Im Gegensatz zu allen anderen `/api/rapt/*`-Endpoints prüft dieser Handler kein `requireRaptCreds`. Damit kann jeder unauthentifiziert das `persistedRaptStartDate` ändern (globaler State im Proxy). **Potenziell ein Bug** — sollte vor Tests an `flutter-coder` zur Klärung gehen. Im Plan: Test asserted aktuelles Verhalten (200 ohne Auth), TODO-Comment im Test für Re-Hardening.
6. **`pubspec.yaml` enthält Repository-Pattern für 9 Manager-Pages** (sichtbar in `main.dart` `BrewMateApp`-Konstruktor). Das deutet auf vorgesehene Widget-Tests in `test/` hin — die `test/`-Directory existiert tatsächlich. Diese sind im Plan ausgeschlossen (Agent-Boundary: E2E only via Playwright), aber wert zu erwähnen: parallele Dart-Widget-Test-Suite könnte schneller + günstiger CRUD-Logik abdecken.
7. **`EnvConfig.studioUrl()` ist conditional** — Studio-Button erscheint nur lokal. Smoke-Suite muss das berücksichtigen (Test darf nicht auf Studio-Button warten gegen Remote).
8. **Vault-Migration ist destruktiv für tests/seeded Keys.** Bei jedem Test-Run der Integrations-Suite wird `vault.secrets` mutiert. Wenn parallele Tests laufen oder CI in der gleichen DB läuft wie der echte User, kollidiert das. Empfehlung: dedizierte Test-DB oder mindestens dedizierter Test-User mit eigener UUID.
