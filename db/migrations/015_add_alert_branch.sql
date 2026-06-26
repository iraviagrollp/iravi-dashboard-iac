-- Adds optional branch scope to alerts (used by sales/sale_returns categories).
-- NULL or 'ALL' = all branches. Applied manually via psql over the SSM tunnel.
ALTER TABLE alerts ADD COLUMN IF NOT EXISTS branch VARCHAR(100);
