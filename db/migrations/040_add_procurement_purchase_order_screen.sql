-- Migration 040: RBAC screen seed for the Procurement Purchase Order screen.
--
-- Top-level nav section (placed before PDC). Lives in the SHARED app_screens table
-- (same RBAC as the main dashboard). Admins map it to roles via the existing Access
-- Control screen. The procurement-ui gates its nav/route on this key; it mirrors
-- procurement-ui/src/screens.ts. (Nav order is controlled in the UI's screens.ts,
-- which places Purchase Order before PDC; app_screens.sort_order is unrelated to
-- that and just appends here at 108.)
--
-- Applied MANUALLY via psql over the SSM bastion tunnel (see migration 026 header).

INSERT INTO app_screens (screen_key, label, sort_order) VALUES
  ('procurement.purchase_orders', 'Purchase Order', 108)
ON CONFLICT (screen_key) DO NOTHING;
