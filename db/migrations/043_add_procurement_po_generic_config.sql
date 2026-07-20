-- Migration 043: add generic_config JSONB to procurement.purchase_orders.
--
-- Backs the new "Generic" PO type (procurement.purchase_orders.po_type = 'GENERIC'),
-- which — unlike the existing 'BULK' (single-line columns) and 'JOB_WORK'
-- (procurement.purchase_order_items grid) PO types — carries a free-form
-- configurable table plus a subject/body, all stored as a single JSONB blob rather
-- than a fixed set of relational columns:
--   {
--     "subject": "...",
--     "body": "...",
--     "columns": ["S No.", "Particulars", ...],
--     "rows": [["1", "...", ...], ...]
--   }
-- "columns" is the ordered list of configurable column headers; "rows" is a list of
-- rows, each a list of cell values in the same order as "columns" (all stored as
-- strings; formatting/rendering is application-side).
--
-- NULL for the existing 'BULK' and 'JOB_WORK' PO types — only 'GENERIC' rows
-- populate this column. Nullable, no default.
--
-- Plain additive column on the existing operational CRUD table (no backfill).
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).
-- Requires migration 039 (purchase_orders) to be applied first.

ALTER TABLE procurement.purchase_orders
  ADD COLUMN IF NOT EXISTS generic_config JSONB;
