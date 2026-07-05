-- Migration 019: add RBAC screen seed for the Monthly Sales report
-- Adds the mappable screen key 'reports.monthly_sales' so that roles can
-- be granted access to the new Monthly Sales report screen in the dashboard
-- (GET /reports/monthly-sales API endpoint; RBAC key mirrors ui/src/screens.ts).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 019_add_monthly_sales_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('reports.monthly_sales', 'Monthly Sales', 92)
ON CONFLICT (screen_key) DO NOTHING;
