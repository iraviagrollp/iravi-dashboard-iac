-- Migration 044: relax NOT NULL on 5 procurement.purchase_orders columns for GENERIC PO type.
--
-- The 'GENERIC' PO type (added by migration 043's generic_config JSONB column) stores its
-- line data as a free-form configurable table + subject/body inside generic_config rather
-- than the fixed relational columns used by 'BULK' and 'JOB_WORK'. Those 5 columns —
-- product_technical_id, quantity, quantity_unit, rate, gst_rate — were declared NOT NULL by
-- migration 039 (written before GENERIC existed) and would raise a NotNullViolation on
-- INSERT/UPDATE of a GENERIC row that leaves them unset.
--
-- This migration drops NOT NULL on exactly those 5 columns. 'BULK' and 'JOB_WORK' rows
-- continue to populate all 5 as before — nothing about their behaviour changes. Per-po_type
-- required-field validation is enforced at the application layer (the procurement_api Lambda
-- handler), so app-level data integrity is preserved even though the DB constraint is relaxed.
--
-- rate and gst_rate keep their existing DEFAULT (0 / 18) — DROP NOT NULL does not remove a
-- column's DEFAULT, it only stops rejecting an explicit NULL. Since GENERIC inserts are
-- expected to omit these columns entirely (letting the DEFAULT apply) or pass NULL
-- explicitly depending on the handler, both paths are now valid.
--
-- ALTER COLUMN ... DROP NOT NULL is idempotent — re-running against a column that already
-- allows NULLs is a no-op, so no IF EXISTS guard is needed.
--
-- Plain constraint relaxation on the existing operational CRUD table (no backfill needed).
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header). Requires
-- migration 039 (purchase_orders) to be applied first.

ALTER TABLE procurement.purchase_orders ALTER COLUMN product_technical_id DROP NOT NULL;
ALTER TABLE procurement.purchase_orders ALTER COLUMN quantity             DROP NOT NULL;
ALTER TABLE procurement.purchase_orders ALTER COLUMN quantity_unit        DROP NOT NULL;
ALTER TABLE procurement.purchase_orders ALTER COLUMN rate                 DROP NOT NULL;
ALTER TABLE procurement.purchase_orders ALTER COLUMN gst_rate             DROP NOT NULL;
