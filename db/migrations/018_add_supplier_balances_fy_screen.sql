-- Migration 018: add RBAC screen seed for the Supplier Balances (FY) report
-- Adds the mappable screen key 'reports.supplier_balances_fy' so that roles can
-- be granted access to the new Supplier Balances (FY) report screen in the dashboard
-- (GET /reports/supplier-balances-fy API endpoint; RBAC key mirrors ui/src/screens.ts).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 018_add_supplier_balances_fy_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('reports.supplier_balances_fy', 'Supplier Balances (FY)', 91)
ON CONFLICT (screen_key) DO NOTHING;
