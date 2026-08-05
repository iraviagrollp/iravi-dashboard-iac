-- Migration 051: add RBAC screen seed for the Issued PDC page
-- Adds the mappable screen key 'suppliers.issued_pdc' so that roles can be
-- granted access to the new read-only Issued PDC page in the dashboard's
-- Suppliers section (GET /pdc and GET /pdc/pdf API endpoints, reading from
-- the procurement.pdc / procurement.supplier_companies / procurement.technicals
-- tables; RBAC key mirrors ui/src/screens.ts). sort_order 95 places it after
-- the existing 'supplier_balances' (93) and 'reports.supplier_ledger_statement'
-- (94) screens, keeping the Suppliers section grouped together.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 051_add_issued_pdc_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('suppliers.issued_pdc', 'Issued PDC', 95)
ON CONFLICT (screen_key) DO NOTHING;

-- After applying, an admin must map the 'suppliers.issued_pdc' screen to the
-- appropriate roles via the Access Control screen in the dashboard UI.
