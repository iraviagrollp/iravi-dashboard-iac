-- 024_create_monthly_collection_targets.sql
-- Monthly Collection Targets — admin-configured per-state collection projections
-- for the "Collection Projection" feature. Natural key: (state, month, yr).
-- business-core closes the open row for a natural key then inserts a fresh
-- one each time a target is edited (uni-temporal milestoning).
-- out_z IS NULL = current (active) record.
--
-- APPLIED MANUALLY via psql over the SSM tunnel — NOT run automatically.
-- Run AFTER terraform apply has provisioned the /config/monthly-collection-targets routes.
--
-- psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin \
--       password='<password>' sslmode=require" \
--      -f db/migrations/024_create_monthly_collection_targets.sql

CREATE TABLE monthly_collection_targets (
    id           BIGSERIAL     PRIMARY KEY,
    state        VARCHAR(10)   NOT NULL,   -- 'AP' | 'TS' | 'TN' | 'OR'
    month        SMALLINT      NOT NULL,   -- 1..12
    yr           SMALLINT      NOT NULL,   -- e.g. 2026
    target_lakhs NUMERIC(14,2) NOT NULL,   -- monthly collection projection, in Lakhs (INR)
    in_z         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    out_z        TIMESTAMPTZ,              -- NULL = current record

    CONSTRAINT chk_monthly_collection_targets_state CHECK (state IN ('AP', 'TS', 'TN', 'OR')),
    CONSTRAINT chk_monthly_collection_targets_month CHECK (month BETWEEN 1 AND 12)
);

-- One active version per (state, month, yr) at a time.
CREATE UNIQUE INDEX uix_monthly_collection_targets_active
    ON monthly_collection_targets (state, month, yr)
    WHERE out_z IS NULL;

CREATE INDEX idx_monthly_collection_targets_yr    ON monthly_collection_targets (yr);
CREATE INDEX idx_monthly_collection_targets_out_z ON monthly_collection_targets (out_z) WHERE out_z IS NULL;
