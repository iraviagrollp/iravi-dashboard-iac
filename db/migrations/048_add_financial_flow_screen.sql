-- Migration 048: add RBAC screen seed for the Financial Flow report
-- Adds the mappable screen key 'reports.financial_flow' so that roles can
-- be granted access to the Financial Flow report screen in the dashboard
-- (RBAC key mirrors ui/src/screens.ts).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 048_add_financial_flow_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('reports.financial_flow', 'Financial Flow', 97)
ON CONFLICT (screen_key) DO NOTHING;
