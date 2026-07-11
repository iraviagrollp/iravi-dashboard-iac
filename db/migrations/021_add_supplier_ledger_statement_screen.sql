-- Migration 021: add RBAC screen seed for the Supplier Ledger Statement report
-- Adds the mappable screen key 'reports.supplier_ledger_statement' so that roles
-- can be granted access to the new Supplier Ledger report screen in the dashboard's
-- Reports section (GET /supplier-ledger/statement API endpoint; RBAC key mirrors
-- iravi-ui/src/screens.ts). Supplier-side counterpart to the customer
-- 'reports.ledger_statement' screen.
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 021_add_supplier_ledger_statement_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('reports.supplier_ledger_statement', 'Supplier Ledger', 94)
ON CONFLICT (screen_key) DO NOTHING;
