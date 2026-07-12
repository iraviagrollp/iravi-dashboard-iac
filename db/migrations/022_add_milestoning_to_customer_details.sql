-- 022_add_milestoning_to_customer_details.sql
-- Adds uni-temporal milestoning (in_z/out_z) to customer_details so the
-- etl_customer_accounts Lambda can retire customers that drop out of the
-- latest "Customer Accounts Export File" instead of just upserting in place.
-- Natural key: customer_name. out_z IS NULL = current (active) record.
--
-- customer_details already has a surrogate `id SERIAL PRIMARY KEY` (from
-- migration 004), so no new surrogate key is introduced here. The blocker is
-- the existing `uq_customer_details_name UNIQUE (customer_name)` constraint
-- (migration 004) — that constraint permits only one row per customer_name
-- ever, which is incompatible with milestoning (many historical rows per
-- name over time). It is dropped and replaced with a PARTIAL unique index
-- that only enforces uniqueness among *active* (out_z IS NULL) rows.
--
-- No FK anywhere in this schema references customer_details(customer_name)
-- or customer_details(id) — confirmed by grep across db/schema.sql and
-- db/migrations/*.sql before writing this migration. Safe to drop the
-- UNIQUE constraint without a wider migration plan.
--
-- Existing rows: `in_z` defaults to NOW() for the backfill and `out_z` stays
-- NULL, i.e. every currently-stored row becomes "active". This is safe
-- because customer_name was unique up to this point, so the new partial
-- unique index (one active row per name) is trivially satisfied on
-- creation — no duplicate-row cleanup is required first.
--
-- APPLIED MANUALLY via psql over the SSM tunnel — NOT run automatically.
--
-- psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin \
--       password='<password>' sslmode=require" \
--      -f db/migrations/022_add_milestoning_to_customer_details.sql

ALTER TABLE customer_details ADD COLUMN IF NOT EXISTS in_z  TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE customer_details ADD COLUMN IF NOT EXISTS out_z TIMESTAMPTZ;              -- NULL = current record

-- Drop the natural-key UNIQUE constraint that blocks multiple historical
-- rows per customer_name (surrogate `id` PK from migration 004 is retained
-- as-is — no need to touch it).
ALTER TABLE customer_details DROP CONSTRAINT IF EXISTS uq_customer_details_name;

-- Enforce one active version per customer_name at a time.
CREATE UNIQUE INDEX IF NOT EXISTS uix_customer_details_active
    ON customer_details (customer_name)
    WHERE out_z IS NULL;

CREATE INDEX IF NOT EXISTS idx_customer_details_out_z ON customer_details (out_z) WHERE out_z IS NULL;
