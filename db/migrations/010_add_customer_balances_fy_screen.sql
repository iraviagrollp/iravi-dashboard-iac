-- Migration 010: add RBAC screen seed for the Customer Balances (FY) report
-- Adds the mappable screen key 'reports.customer_balances_fy' so that roles can
-- be granted access to the new Customer Balances (FY) report screen in the dashboard
-- (GET /reports/customer-balances-fy API endpoint; RBAC key mirrors ui/src/screens.ts).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 010_add_customer_balances_fy_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('reports.customer_balances_fy', 'Customer Balances (FY)', 90)
ON CONFLICT (screen_key) DO NOTHING;
