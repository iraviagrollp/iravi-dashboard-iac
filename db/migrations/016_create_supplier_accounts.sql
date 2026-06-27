-- 016_create_supplier_accounts.sql
-- Supplier master data from FUSIL PRO "Supplier Accounts Export File" export.
-- Natural key: name (supplier name). business-core closes the open row for a name
-- then inserts a fresh one each run (uni-temporal milestoning).
-- out_z IS NULL = current (active) record.
--
-- APPLIED MANUALLY via psql over the SSM tunnel — NOT run automatically.
-- Run AFTER terraform apply has provisioned lambda_etl_supplier_accounts.
--
-- psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin \
--       password='<password>' sslmode=require" \
--      -f db/migrations/016_create_supplier_accounts.sql

CREATE TABLE supplier_accounts (
    id        BIGSERIAL PRIMARY KEY,
    name      VARCHAR(255)  NOT NULL,
    gst       VARCHAR(20),
    gst_valid BOOLEAN,
    city      VARCHAR(120),
    state     VARCHAR(100),
    in_z      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    out_z     TIMESTAMPTZ             -- NULL = current record
);

-- Enforce one active version per supplier name at a time.
CREATE UNIQUE INDEX uix_supplier_accounts_active
    ON supplier_accounts (name)
    WHERE out_z IS NULL;

CREATE INDEX idx_supplier_accounts_name  ON supplier_accounts (name);
CREATE INDEX idx_supplier_accounts_out_z ON supplier_accounts (out_z) WHERE out_z IS NULL;
