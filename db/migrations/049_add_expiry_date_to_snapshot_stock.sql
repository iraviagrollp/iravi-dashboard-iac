-- Migration 049: add expiry_date to snapshot_stock (Stock Expiry page)
-- The upstream stock export (RGF Current Stock Balances) now carries a 44th
-- trailing column, ExpiryDate ("DD-MM-YYYY HH:MM:SS", e.g. "21-08-2027 00:00:00").
-- Business decision: stock is now tracked at ONE ROW PER DISTINCT EXPIRY DATE, so
-- expiry_date becomes part of snapshot_stock's uni-temporal natural key.
--
-- This migration:
--   1. Adds the nullable expiry_date DATE column (nullable because some rows may
--      legitimately have no expiry, and to keep the ALTER safe against existing data).
--   2. Drops and recreates the partial unique index uix_stock_active to include
--      expiry_date in the natural key, via COALESCE(expiry_date, '9999-12-31') —
--      Postgres treats NULLs as always-distinct in a unique index, so the bare
--      column would NOT de-duplicate no-expiry rows against each other. Coalescing
--      to a sentinel date keeps exactly one active row per no-expiry natural key,
--      same as before this migration, while genuinely distinct expiry dates each
--      get their own active row.
--   3. Adds idx_stock_expiry_date for expiry-based queries (Stock Expiry page).
--
-- Idempotent / safely re-runnable: ADD COLUMN IF NOT EXISTS, DROP INDEX IF EXISTS,
-- CREATE INDEX IF NOT EXISTS throughout.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 049_add_expiry_date_to_snapshot_stock.sql

ALTER TABLE snapshot_stock ADD COLUMN IF NOT EXISTS expiry_date DATE;

DROP INDEX IF EXISTS uix_stock_active;

CREATE UNIQUE INDEX IF NOT EXISTS uix_stock_active
    ON snapshot_stock (brand, technical, packing_size, packing_configuration,
                       branch, special_packing_mention, entry_date,
                       COALESCE(expiry_date, '9999-12-31'::date))
    WHERE out_z IS NULL;

CREATE INDEX IF NOT EXISTS idx_stock_expiry_date ON snapshot_stock (expiry_date);
