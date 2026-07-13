-- Migration 029: RBAC screen seed for the Procurement dashboard Overview page.
--
-- The Overview is the Procurement dashboard's landing page (aggregate tiles:
-- enquiry / PDC / technical / supplier / company counts + PDC amounts). Its
-- screen_key lives in the SHARED app_screens table, so admins map it to roles
-- from the existing Access Control screen — same pattern as migration 027.
-- Mirrors procurement-ui/src/screens.ts ('procurement.overview'). sort_order 99
-- keeps it above the Setup screens (100+) so it is the first-allowed landing.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

INSERT INTO app_screens (screen_key, label, sort_order) VALUES
  ('procurement.overview', 'Procurement Overview', 99)
ON CONFLICT (screen_key) DO NOTHING;
