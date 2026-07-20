-- Migration 042: add include_terms toggle to procurement.purchase_orders.
--
-- Backs a per-PO toggle to include/exclude the Terms & Conditions section on the
-- generated Purchase Order PDF (applies to both the existing 'BULK' PO type and the
-- new 'JOB_WORK' PO type — both types render off the same purchase_orders row).
--
-- DEFAULT TRUE preserves current behaviour: existing rows keep showing T&C on the
-- printed PDF exactly as before this migration.
--
-- Plain additive column on the existing operational CRUD table (no backfill needed
-- beyond the default). Applied MANUALLY via psql over the SSM bastion tunnel (see
-- migration 026 header). Requires migration 039 (purchase_orders) to be applied first.

ALTER TABLE procurement.purchase_orders
  ADD COLUMN IF NOT EXISTS include_terms BOOLEAN NOT NULL DEFAULT TRUE;
