-- Migration 039: create procurement.purchase_orders (Bulk Purchase Orders).
--
-- Backs the Procurement dashboard's new "Purchase Order" section. First PO type is
-- 'BULK' (po_type left extensible for future types). Reference layout:
-- D:\2026\IRA\Reports\POs\Bulk\IAL PO for PENOXSULAM 1.02 OD.pdf.
--
-- PO number is a per-financial-year sequence: 'IAL/{fy}/{po_seq}' where fy is the
-- 4-digit FY code (e.g. '2627' for FY 2026-27, Apr-Mar) and po_seq is the running
-- serial within that FY, enforced unique by (fy, po_seq).
-- Supplier / Bill To / Ship To all reference procurement.supplier_companies (their
-- address_line*/state/gstin columns render on the PO). Product references a
-- technical; the signatory references signatory_authorities.
--
-- Plain operational CRUD table (updated_at trigger). Applied MANUALLY via psql over
-- the SSM bastion tunnel (see migration 026 header). Requires migrations 026
-- (supplier_companies, technicals), 032 (supplier-company address columns) and 037
-- (signatory_authorities) to be applied first.

CREATE TABLE IF NOT EXISTS procurement.purchase_orders (
  id                   BIGSERIAL PRIMARY KEY,
  po_type              VARCHAR(20) NOT NULL DEFAULT 'BULK',
  po_no                VARCHAR(40) NOT NULL,
  po_date              DATE NOT NULL,
  fy                   VARCHAR(9) NOT NULL,               -- financial-year code, e.g. '2627' (FY 2026-27)
  po_seq               INTEGER NOT NULL,                  -- running serial within the FY
  supplier_company_id  BIGINT NOT NULL REFERENCES procurement.supplier_companies(id) ON DELETE RESTRICT,
  product_technical_id BIGINT NOT NULL REFERENCES procurement.technicals(id) ON DELETE RESTRICT,
  quantity             NUMERIC(16,2) NOT NULL,
  quantity_unit        VARCHAR(10) NOT NULL,              -- 'KGS' | 'LTRS'
  rate                 NUMERIC(14,2) NOT NULL DEFAULT 0,  -- ₹ per unit (Amount = quantity * rate)
  gst_rate             NUMERIC(5,2) NOT NULL DEFAULT 18,  -- GST %
  terms                VARCHAR(300),
  dispatch             VARCHAR(300),
  transport            VARCHAR(300),
  bill_to_company_id   BIGINT REFERENCES procurement.supplier_companies(id) ON DELETE SET NULL,
  ship_to_company_id   BIGINT REFERENCES procurement.supplier_companies(id) ON DELETE SET NULL,
  signatory_id         BIGINT REFERENCES procurement.signatory_authorities(id) ON DELETE SET NULL,
  note                 TEXT DEFAULT 'Attach Tech. Grade Standards & COA along with your Invoice',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_purchase_orders_po_no UNIQUE (po_no)
);

-- PO number is 'IAL/{fy}/{po_seq}' — serial resets per financial year.
CREATE UNIQUE INDEX IF NOT EXISTS uq_purchase_orders_fy_seq ON procurement.purchase_orders(fy, po_seq);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_date ON procurement.purchase_orders(po_date);

DROP TRIGGER IF EXISTS trg_purchase_orders_touch ON procurement.purchase_orders;
CREATE TRIGGER trg_purchase_orders_touch
  BEFORE UPDATE ON procurement.purchase_orders
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();
