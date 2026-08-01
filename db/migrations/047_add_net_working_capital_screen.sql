-- Migration 047: add RBAC screen seed for the Net Working Capital Position report
-- Adds the mappable screen key 'reports.net_working_capital' so that roles can
-- be granted access to the Net Working Capital Position report screen in the
-- dashboard (RBAC key mirrors ui/src/screens.ts).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 047_add_net_working_capital_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('reports.net_working_capital', 'Net Working Capital Position', 96)
ON CONFLICT (screen_key) DO NOTHING;
