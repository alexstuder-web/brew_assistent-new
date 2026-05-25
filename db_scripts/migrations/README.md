# aibrewgenius — db_scripts/migrations/

New schema changes that come **after** `db_scripts/full/baseline.sql` go here as `NNN_*.sql` files.

## Convention

| Rule | Detail |
|---|---|
| **Naming** | `NNN_short_description.sql` — 3-digit zero-padded number, e.g. `001_add_hop_color.sql` |
| **Version format** | `'001'`, `'010'`, `'100'` — identical numeric string inserted into `public.schema_migrations` |
| **Starting point** | `baseline.sql` seeds version `'000'`. Numbered migrations start at `'001'`, forward-only, no gaps, never renumber. |
| **Apply condition** | Runner applies files whose version is NOT yet in `public.schema_migrations`. |
| **Never edit applied** | Once a migration has run on any live DB, it is immutable. Fix-forward with a new migration. |
| **Idempotent** | `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `ADD COLUMN IF NOT EXISTS`, `DROP POLICY IF EXISTS` + `CREATE POLICY`, `CREATE INDEX IF NOT EXISTS`. |
| **Transactional** | `BEGIN; … COMMIT;` wraps the full file. The version INSERT is the last statement inside the transaction so a DDL error rolls back the version row too. |
| **DDL role** | Runner connects as `supabase_admin`. Never write DDL that requires `postgres` superuser. |

## Template

Copy `_TEMPLATE.sql`, rename to `NNN_*.sql`, fill in the header + DDL, update the version string in the final `INSERT`. The leading underscore excludes `_TEMPLATE.sql` from the runner discovery pattern `^[0-9]{3}_.*\.sql$`.

## archive/

Contains the historical migration chain before the Per-App-Baseline-Cut (2026-05-25). **Never touch archive/ again** — those migrations are superseded by `baseline.sql` and must never be re-applied. The runner never scans `archive/`.
