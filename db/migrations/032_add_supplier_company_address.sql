-- 032_add_supplier_company_address.sql
-- Extend procurement.supplier_companies with a structured postal address + GSTIN.
--
-- The Supplier Company Configuration screen previously carried only company_name +
-- a single free-text `location`. Procurement now needs the full billing address
-- (three address lines, State, PIN) and the company's GSTIN. These are added as
-- nullable columns so existing rows (seeded by migration 028) are unaffected; the
-- legacy `location` column is retained for backward compatibility.
--
-- Additive only — safe to run on a live table.

BEGIN;

ALTER TABLE procurement.supplier_companies
  ADD COLUMN IF NOT EXISTS address_line1 VARCHAR(200),
  ADD COLUMN IF NOT EXISTS address_line2 VARCHAR(200),
  ADD COLUMN IF NOT EXISTS address_line3 VARCHAR(200),
  ADD COLUMN IF NOT EXISTS state         VARCHAR(100),
  ADD COLUMN IF NOT EXISTS pin_code      VARCHAR(10),
  ADD COLUMN IF NOT EXISTS gstin         VARCHAR(20);

COMMIT;
