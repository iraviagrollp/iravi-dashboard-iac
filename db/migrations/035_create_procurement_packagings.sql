-- Migration 035: create procurement.packagings — packaging sizes assigned per brand.
--
-- Each technical carries a brand (procurement.technicals.brand_name). This table
-- links a brand (via technical_id, the brand carrier) to one packaging size chosen
-- from the master list (procurement.packaging_meta). One row per (brand, size).
-- The UI cascade is: pick Brand, then Unit type (KG/LTR), then the Size from the
-- meta list for that unit.
--
-- Plain operational CRUD table (is_active + updated_at trigger). Applied MANUALLY
-- via psql over the SSM bastion tunnel (see migration 026 header). Requires
-- migrations 033 (packaging_meta) and 026 (technicals) to be applied first.

CREATE TABLE IF NOT EXISTS procurement.packagings (
  id                BIGSERIAL PRIMARY KEY,
  technical_id      BIGINT NOT NULL REFERENCES procurement.technicals(id) ON DELETE CASCADE,
  packaging_meta_id BIGINT NOT NULL REFERENCES procurement.packaging_meta(id) ON DELETE RESTRICT,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_packagings_technical_meta UNIQUE (technical_id, packaging_meta_id)
);

CREATE INDEX IF NOT EXISTS idx_packagings_technical ON procurement.packagings(technical_id);
CREATE INDEX IF NOT EXISTS idx_packagings_meta      ON procurement.packagings(packaging_meta_id);

DROP TRIGGER IF EXISTS trg_packagings_touch ON procurement.packagings;
CREATE TRIGGER trg_packagings_touch
  BEFORE UPDATE ON procurement.packagings
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();
