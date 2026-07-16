-- Migration 033: create procurement.packagings — packaging sizes per brand.
--
-- Each technical carries a brand (procurement.technicals.brand_name). A brand is
-- sold in several packaging sizes (e.g. ACEPRIDE → 1 KG, 500 GM, 250 GM, 100 GM,
-- 100 GM Box, 50 GM, 50 GM Box — see design/Opening Stock 15-Jul-2026.pdf). This
-- table holds one row per (brand/technical, packaging label). It is keyed on
-- technical_id (the brand carrier) so packaging inherits the brand via FK; the
-- procurement-ui surfaces it as "Brand".
--
-- Plain operational CRUD table (is_active + updated_at trigger), matching the rest
-- of the procurement schema. Applied MANUALLY via psql over the SSM bastion tunnel
-- (see migration 026 header for the connection command).

CREATE TABLE IF NOT EXISTS procurement.packagings (
  id           BIGSERIAL PRIMARY KEY,
  technical_id BIGINT NOT NULL REFERENCES procurement.technicals(id) ON DELETE CASCADE,
  packaging    VARCHAR(100) NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_packagings_technical_packaging UNIQUE (technical_id, packaging)
);

CREATE INDEX IF NOT EXISTS idx_packagings_technical ON procurement.packagings(technical_id);

DROP TRIGGER IF EXISTS trg_packagings_touch ON procurement.packagings;
CREATE TRIGGER trg_packagings_touch
  BEFORE UPDATE ON procurement.packagings
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();
