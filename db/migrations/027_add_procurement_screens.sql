-- Migration 027: RBAC screen seeds for the Procurement dashboard Setup sections.
--
-- These keys live in the SHARED app_screens table (same RBAC used by the main
-- dashboard) so admins map them to roles from the existing Access Control screen.
-- The procurement-ui gates its nav/routes on these keys; keys mirror
-- procurement-ui/src/screens.ts.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

INSERT INTO app_screens (screen_key, label, sort_order) VALUES
  ('procurement.technicals',         'Technical Configuration',         100),
  ('procurement.suppliers',          'Supplier Configuration',          101),
  ('procurement.supplier_companies', 'Supplier Company Configuration',  102),
  ('procurement.enquiries',          'Enquiries',                       103),
  ('procurement.pdc',                'Post-Dated Cheques (PDC)',        104)
ON CONFLICT (screen_key) DO NOTHING;
