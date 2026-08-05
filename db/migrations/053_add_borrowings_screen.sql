-- Migration 053: add RBAC screen seed for the Borrowings page
-- Adds the mappable screen key 'finances.borrowings' so that roles can be
-- granted access to the new Borrowings page in the dashboard (GET /borrowings/meta
-- and GET /borrowings API endpoints; RBAC key mirrors ui/src/screens.ts).
--
-- sort_order note: the requested placement was "after all suppliers.*/supplier
-- screens and before the reports.* screens". Inspecting the current seed data,
-- the two clusters are NOT cleanly separated — reports.supplier_balances_fy (91)
-- and reports.supplier_ledger_statement (94) already sit *inside* the
-- supplier_balances (93) / suppliers.issued_pdc (95) run, and reports.monthly_collection
-- (025) already shares the value 95 with suppliers.issued_pdc (051). The last
-- supplier-ish screen is suppliers.issued_pdc at 95 and the next screens are
-- reports.net_working_capital (96) / reports.financial_flow (97) — adjacent
-- integers with no room between them. Per instructions we did NOT renumber any
-- existing screen. sort_order 96 was chosen, tying with reports.net_working_capital
-- (this table already tolerates duplicate sort_order values — see 95 above) so
-- Borrowings sorts at/after the end of the Suppliers-related screens and no later
-- than the tail Reports screens. Flagged for the requester; a full renumbering
-- pass (e.g. re-seeding all sort_order values in steps of 10) would be needed to
-- get a clean, gap-free ordering.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 053_add_borrowings_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('finances.borrowings', 'Borrowings', 96)
ON CONFLICT (screen_key) DO NOTHING;

-- After applying, an admin must map the 'finances.borrowings' screen to the
-- appropriate roles via the Access Control screen in the dashboard UI.
-- (Mirroring 050/051/019/018/010: this seed does NOT auto-grant the screen to
-- the Administrator role — Administrator is is_admin=TRUE in app_roles and
-- already implicitly sees every screen without an app_role_screens row.)
