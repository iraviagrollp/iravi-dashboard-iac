-- Migration 054: create borrowing_rate table
-- Applied MANUALLY via psql over the SSM tunnel; NOT automatic.
-- Run AFTER terraform apply has provisioned the /config/borrowing-rates routes.
--
-- Admin-configured per-account interest rate on borrowings, for the new
-- Config screen. Modelled on 023_create_monthly_sale_targets.sql — same
-- uni-temporal milestoning shape (in_z/out_z, partial unique index on the
-- active row). Table name is deliberately singular (borrowing_rate), unlike
-- most other tables in this repo, per explicit request.
--
-- rate    = annual interest rate on the account's borrowings, expressed in
--           percent (e.g. 12.500 = 12.5% p.a.).
-- account = free text matching borrowings.account. There is deliberately NO
--           foreign key to borrowings: accounts are free text sourced from
--           the ERP export, and a rate may be configured for an account
--           before its first borrowings transaction lands (or after the
--           account has gone quiet), so a hard FK would be too restrictive.
--
-- natural key: (account)
-- out_z IS NULL  → current (active) record
-- out_z IS NOT NULL → superseded; kept for audit history
--
-- psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin \
--       password='<password>' sslmode=require" \
--      -f db/migrations/054_create_borrowing_rate.sql

CREATE TABLE borrowing_rate (
    id      BIGSERIAL     PRIMARY KEY,
    account TEXT          NOT NULL,      -- matches borrowings.account
    rate    NUMERIC(6,3)  NOT NULL,      -- annual interest rate, percent
    in_z    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    out_z   TIMESTAMPTZ,                 -- NULL = current record

    CONSTRAINT chk_borrowing_rate_rate CHECK (rate >= 0 AND rate <= 100)
);

-- One active version per account at a time.
CREATE UNIQUE INDEX uix_borrowing_rate_active
    ON borrowing_rate (account)
    WHERE out_z IS NULL;
