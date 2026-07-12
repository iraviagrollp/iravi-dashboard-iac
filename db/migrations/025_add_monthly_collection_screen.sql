-- Migration 025: add RBAC screen seed for the Monthly Collection report
-- Adds the mappable screen key 'reports.monthly_collection' so that roles can
-- be granted access to the new Monthly Collection report screen in the dashboard
-- (GET /reports/monthly-collection API endpoint; RBAC key mirrors ui/src/screens.ts).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 025_add_monthly_collection_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('reports.monthly_collection', 'Monthly Collection', 95)
ON CONFLICT (screen_key) DO NOTHING;
