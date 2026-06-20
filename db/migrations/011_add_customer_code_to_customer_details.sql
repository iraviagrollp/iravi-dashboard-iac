-- Adds customer_code (party code, e.g. ANK001) to customer_details.
-- Sourced from the "General" sheet of the Customer Accounts Export File by the
-- etl_customer_accounts Lambda. Applied manually via psql over the SSM tunnel
-- (migrations are never auto-applied). Must be applied BEFORE the updated
-- etl_customer_accounts Lambda runs, otherwise its upsert referencing
-- customer_code will fail.
ALTER TABLE customer_details ADD COLUMN IF NOT EXISTS customer_code VARCHAR(20);
CREATE INDEX IF NOT EXISTS idx_customer_details_code ON customer_details (customer_code);
