-- Migration 041: create procurement.purchase_order_items (multi-row particulars grid).
--
-- Backs the new "Job Work" PO type (procurement.purchase_orders.po_type = 'JOB_WORK'),
-- which — unlike the existing single-line 'BULK' PO — has a multi-row particulars
-- grid (one row per technical/packaging/quantity/rate line). Bulk POs continue to
-- use the single-line columns already on purchase_orders (product_technical_id /
-- quantity / rate / gst_rate); this table is populated only for PO types that need
-- multiple line items.
--
-- One row per particular line on a PO. `sl_no` is the 1-based row order shown on
-- the printed PO; unique per po_id so a PO's grid can be rebuilt (delete + reinsert)
-- on every edit without leaving gaps or duplicates.
-- `packaging_id` is nullable — not every line necessarily has a configured packing
-- size (mirrors procurement.packagings, which is itself optional per technical).
-- `quantity` is stored in the PO's base unit (KGS for KG/TONNE, LTRS for LTR/KL —
-- same convention as purchase_orders.quantity_unit); `amount` = quantity * rate,
-- computed application-side and stored for the printed PDF / list views.
--
-- Plain operational CRUD table (no is_active / updated_at trigger — rows are
-- replaced wholesale whenever a PO's grid is edited, not soft-updated in place).
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).
-- Requires migrations 039 (purchase_orders), 026 (technicals) and 035 (packagings)
-- to be applied first.

CREATE TABLE IF NOT EXISTS procurement.purchase_order_items (
  id           BIGSERIAL PRIMARY KEY,
  po_id        BIGINT NOT NULL REFERENCES procurement.purchase_orders(id) ON DELETE CASCADE,
  sl_no        INTEGER NOT NULL,
  technical_id BIGINT NOT NULL REFERENCES procurement.technicals(id) ON DELETE RESTRICT,
  packaging_id BIGINT REFERENCES procurement.packagings(id) ON DELETE RESTRICT,
  quantity     NUMERIC(16,2) NOT NULL,      -- base unit: KGS (KG/TONNE) or LTRS (LTR/KL)
  rate         NUMERIC(14,2) NOT NULL DEFAULT 0,
  amount       NUMERIC(16,2) NOT NULL DEFAULT 0,  -- quantity * rate
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_purchase_order_items_po_sl UNIQUE (po_id, sl_no)
);

CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po ON procurement.purchase_order_items(po_id);
