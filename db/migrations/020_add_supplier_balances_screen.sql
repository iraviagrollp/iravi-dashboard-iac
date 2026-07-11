-- Migration 020: add RBAC screen seed for the Supplier Balances (aging) screen
-- Adds the mappable screen key 'supplier_balances' so that roles can be granted
-- access to the new Supplier Balances aging screen in the dashboard's Suppliers
-- section (GET /supplier-ledger, /supplier-ledger/range, /suppliers/details API
-- endpoints; RBAC key mirrors iravi-ui/src/screens.ts). This is the supplier-side
-- counterpart to the customer 'balances' screen (aging of payables by credit).
--
-- Applied MANUALLY via psql over the SSM bastion tunnel — migrations are NEVER
-- auto-applied by Terraform or CI. To apply:
--   aws ssm start-session --target <bastion-instance-id> \
--     --document-name AWS-StartPortForwardingSession \
--     --parameters '{"portNumber":["5432"],"localPortNumber":["5433"]}'
--   psql -h 127.0.0.1 -p 5433 -U dashboard_admin -d iravi_dashboard \
--     -f 020_add_supplier_balances_screen.sql

INSERT INTO app_screens (screen_key, label, sort_order)
VALUES ('supplier_balances', 'Supplier Balances', 93)
ON CONFLICT (screen_key) DO NOTHING;
