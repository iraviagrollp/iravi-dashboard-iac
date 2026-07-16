-- Migration 036: RBAC screen seeds for the Procurement packaging screens.
--
-- Two screens: the master size lists (procurement.packaging_meta) and the per-brand
-- assignment (procurement.packagings). Both live in the SHARED app_screens table
-- (same RBAC as the main dashboard). Admins map them to roles via the existing
-- Access Control screen. Keys mirror procurement-ui/src/screens.ts.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

INSERT INTO app_screens (screen_key, label, sort_order) VALUES
  ('procurement.packaging_meta', 'Packaging Meta Configuration', 105),
  ('procurement.packagings',     'Packaging Configuration',      106)
ON CONFLICT (screen_key) DO NOTHING;
