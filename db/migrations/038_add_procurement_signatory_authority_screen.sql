-- Migration 038: RBAC screen seed for the Procurement Signatory Authority screen.
--
-- Lives in the SHARED app_screens table (same RBAC as the main dashboard). Admins
-- map it to roles via the existing Access Control screen. The procurement-ui gates
-- its nav/route on this key; it mirrors procurement-ui/src/screens.ts.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

INSERT INTO app_screens (screen_key, label, sort_order) VALUES
  ('procurement.signatory_authorities', 'Signatory Authority', 107)
ON CONFLICT (screen_key) DO NOTHING;
