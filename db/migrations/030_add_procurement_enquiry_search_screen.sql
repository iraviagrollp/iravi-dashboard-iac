-- Migration 030: RBAC screen seed for the Procurement dashboard Enquiry Search page.
--
-- Enquiry Search is a read-only lookup screen: search the enquiries either by
-- technical or by supplier and list every matching enquiry (lowest-rate row
-- highlighted when searching by technical). It reads the existing GET /enquiries
-- data client-side — no new API route or table. Its screen_key lives in the
-- SHARED app_screens table so admins map it to roles from Access Control, same
-- pattern as migrations 027/029. Mirrors procurement-ui/src/screens.ts
-- ('procurement.enquiry_search'). sort_order 105 keeps it after the Setup screens.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

INSERT INTO app_screens (screen_key, label, sort_order) VALUES
  ('procurement.enquiry_search', 'Enquiry Search', 105)
ON CONFLICT (screen_key) DO NOTHING;
