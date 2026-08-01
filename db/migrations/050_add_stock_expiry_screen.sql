-- Migration 050: add RBAC screen seed for the Stock Expiry page
-- Adds the mappable screen key 'stocks.expiry' so that roles can be granted
-- access to the new Stock Expiry page in the dashboard (GET /stocks/expiry and
-- GET /stocks/expiry/pdf API endpoints; RBAC key mirrors ui/src/screens.ts).
-- sort_order 41 places it immediately after the existing 'stocks' screen (40)
-- and before 'customers' (50).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 050_add_stock_expiry_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('stocks.expiry', 'Stock Expiry', 41)
ON CONFLICT (screen_key) DO NOTHING;

-- After applying, an admin must map the 'stocks.expiry' screen to the
-- appropriate roles via the Access Control screen in the dashboard UI.
