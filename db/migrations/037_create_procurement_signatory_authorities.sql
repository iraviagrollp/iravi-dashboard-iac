-- Migration 037: create procurement.signatory_authorities.
--
-- Master list of people authorised to sign procurement documents. Plain fields:
-- name, title, department. Plain operational CRUD table (is_active + updated_at
-- trigger), matching the rest of the procurement schema.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

CREATE TABLE IF NOT EXISTS procurement.signatory_authorities (
  id         BIGSERIAL PRIMARY KEY,
  name       VARCHAR(200) NOT NULL,
  title      VARCHAR(200),
  department VARCHAR(200),
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_signatory_authorities_name UNIQUE (name)
);

DROP TRIGGER IF EXISTS trg_signatory_authorities_touch ON procurement.signatory_authorities;
CREATE TRIGGER trg_signatory_authorities_touch
  BEFORE UPDATE ON procurement.signatory_authorities
  FOR EACH ROW EXECUTE FUNCTION procurement.touch_updated_at();
