-- Migration 026: create the `procurement` schema + operational CRUD tables.
--
-- Powers the Procurement team dashboard (procurement.iraviagrolife.com), served by
-- the new `procurement_api` Lambda. These are plain operational CRUD tables
-- (is_active flag + updated_at) — NOT the uni-temporal milestoning used by the ETL
-- snapshot/ledger tables — because this is hand-entered configuration/operational
-- data, not a nightly full-snapshot feed.
--
-- Source of the data model: IaC/design/IAL Enquiry.xlsx
--   Master       -> procurement.technicals
--   Comparision  -> procurement.enquiries (COMPANY col = "Contact Person - Supplier Company")
--   PDC          -> procurement.pdc
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 026_create_procurement_schema.sql

CREATE SCHEMA IF NOT EXISTS procurement;

-- Shared trigger: keep updated_at fresh on every UPDATE.
CREATE OR REPLACE FUNCTION procurement.touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── Supplier Companies ────────────────────────────────────────────────────────
-- Section 3: company name + location.
CREATE TABLE IF NOT EXISTS procurement.supplier_companies (
  id           BIGSERIAL PRIMARY KEY,
  company_name VARCHAR(200) NOT NULL,
  location     VARCHAR(200),
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_supplier_companies_name UNIQUE (company_name)
);

DROP TRIGGER IF EXISTS trg_supplier_companies_touch ON procurement.supplier_companies;
CREATE TRIGGER trg_supplier_companies_touch
  BEFORE UPDATE ON procurement.supplier_companies
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();

-- ── Technicals ────────────────────────────────────────────────────────────────
-- Section 1: technical name + brand name (from the Master sheet).
CREATE TABLE IF NOT EXISTS procurement.technicals (
  id             BIGSERIAL PRIMARY KEY,
  technical_name VARCHAR(300) NOT NULL,
  brand_name     VARCHAR(200),
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_technicals_name UNIQUE (technical_name)
);

DROP TRIGGER IF EXISTS trg_technicals_touch ON procurement.technicals;
CREATE TRIGGER trg_technicals_touch
  BEFORE UPDATE ON procurement.technicals
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();

-- ── Suppliers (contact person @ supplier company) ─────────────────────────────
-- Section 2: contact person name + supplier company (FK dropdown).
CREATE TABLE IF NOT EXISTS procurement.suppliers (
  id                  BIGSERIAL PRIMARY KEY,
  contact_person_name VARCHAR(200) NOT NULL,
  company_id          BIGINT NOT NULL REFERENCES procurement.supplier_companies(id) ON DELETE RESTRICT,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_suppliers_person_company UNIQUE (contact_person_name, company_id)
);

CREATE INDEX IF NOT EXISTS idx_suppliers_company ON procurement.suppliers(company_id);

DROP TRIGGER IF EXISTS trg_suppliers_touch ON procurement.suppliers;
CREATE TRIGGER trg_suppliers_touch
  BEFORE UPDATE ON procurement.suppliers
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();

-- ── Enquiries (market quotations) ─────────────────────────────────────────────
-- Section 4: date, technical (FK), supplier (FK, shown as "Name - Company"), rate.
CREATE TABLE IF NOT EXISTS procurement.enquiries (
  id           BIGSERIAL PRIMARY KEY,
  enquiry_date DATE NOT NULL,
  technical_id BIGINT NOT NULL REFERENCES procurement.technicals(id) ON DELETE RESTRICT,
  supplier_id  BIGINT NOT NULL REFERENCES procurement.suppliers(id) ON DELETE RESTRICT,
  rate         NUMERIC(14,2) NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_enquiries_date     ON procurement.enquiries(enquiry_date);
CREATE INDEX IF NOT EXISTS idx_enquiries_technical ON procurement.enquiries(technical_id);
CREATE INDEX IF NOT EXISTS idx_enquiries_supplier ON procurement.enquiries(supplier_id);

DROP TRIGGER IF EXISTS trg_enquiries_touch ON procurement.enquiries;
CREATE TRIGGER trg_enquiries_touch
  BEFORE UPDATE ON procurement.enquiries
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();

-- ── PDC (post-dated cheques) ──────────────────────────────────────────────────
-- Section 5: mirrors the PDC sheet columns. Supplier = supplier company (FK dropdown),
-- Product = technical (FK dropdown); Brand is captured from the chosen technical.
-- FKs are nullable + ON DELETE SET NULL so deleting a config row never destroys
-- historical cheque records.
CREATE TABLE IF NOT EXISTS procurement.pdc (
  id                   BIGSERIAL PRIMARY KEY,
  po_no                VARCHAR(50),
  po_date              DATE,
  supplier_company_id  BIGINT REFERENCES procurement.supplier_companies(id) ON DELETE SET NULL,
  technical_id         BIGINT REFERENCES procurement.technicals(id) ON DELETE SET NULL,
  brand                VARCHAR(200),
  credit_days          INTEGER,
  qty                  NUMERIC(16,2),
  rate                 NUMERIC(16,2),
  gross                NUMERIC(18,2),
  gst                  NUMERIC(18,2),
  amount               NUMERIC(18,2),
  disc                 NUMERIC(18,2),
  adv                  NUMERIC(18,2),
  bal                  NUMERIC(18,2),
  pdc_amt              NUMERIC(18,2),
  pdc_date             DATE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pdc_po_date  ON procurement.pdc(po_date);
CREATE INDEX IF NOT EXISTS idx_pdc_pdc_date ON procurement.pdc(pdc_date);
CREATE INDEX IF NOT EXISTS idx_pdc_supplier ON procurement.pdc(supplier_company_id);

DROP TRIGGER IF EXISTS trg_pdc_touch ON procurement.pdc;
CREATE TRIGGER trg_pdc_touch
  BEFORE UPDATE ON procurement.pdc
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();
