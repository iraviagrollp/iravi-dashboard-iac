-- Migration 033: create procurement.packaging_meta — master packaging sizes per unit type.
--
-- Two unit types: 'KG' (weight — 1 KG, 500 GM, 100 GM (B), …) and 'LTR' (volume —
-- 1 LT, 500 ML, 250 ML, …). One row per (unit_type, label). The per-product
-- packaging config (migration 035) references these rows; its UI is a cascade —
-- pick the unit type first, then the size from this list (ordered by sort_order,
-- largest on top). See design/Opening Stock 15-Jul-2026.pdf for the source sizes.
--
-- Plain operational CRUD table (is_active + updated_at trigger), matching the rest
-- of the procurement schema. Applied MANUALLY via psql over the SSM bastion tunnel
-- (see migration 026 header for the connection command).

CREATE TABLE IF NOT EXISTS procurement.packaging_meta (
  id         BIGSERIAL PRIMARY KEY,
  unit_type  VARCHAR(10) NOT NULL,          -- 'KG' | 'LTR'
  label      VARCHAR(100) NOT NULL,         -- e.g. '1 KG', '500 GM', '100 GM (B)', '1 LT', '500 ML'
  sort_order INTEGER NOT NULL DEFAULT 100,  -- ascending = top-to-bottom (largest size first)
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_packaging_meta_unit_label UNIQUE (unit_type, label)
);

CREATE INDEX IF NOT EXISTS idx_packaging_meta_unit ON procurement.packaging_meta(unit_type, sort_order);

DROP TRIGGER IF EXISTS trg_packaging_meta_touch ON procurement.packaging_meta;
CREATE TRIGGER trg_packaging_meta_touch
  BEFORE UPDATE ON procurement.packaging_meta
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();
