-- Migration 052: create borrowings table
-- Applied MANUALLY via psql over the SSM tunnel; NOT automatic.
-- Run AFTER terraform apply has provisioned lambda_etl_borrowings.tf.
--
-- Tracks money borrowed from / repaid to investors (LLP partners or external
-- lenders). Modelled on 017_create_supplier_ledger.sql — same uni-temporal
-- milestoning shape (in_z/out_z, partial unique index on the active row).
--
-- debit  = money paid BY the firm TO the investor (a repayment of borrowed funds).
-- credit = money received BY the firm FROM the investor (a new borrowing).
--
-- natural key: (transaction_date, voucher_no, account)
-- out_z IS NULL  → current (active) record
-- out_z IS NOT NULL → superseded; kept for audit history

CREATE TABLE IF NOT EXISTS borrowings (
    id               BIGSERIAL PRIMARY KEY,
    transaction_date DATE           NOT NULL,
    voucher_no       TEXT           NOT NULL,
    transaction_name TEXT,
    account          TEXT           NOT NULL,
    debit            NUMERIC(18, 2) NOT NULL DEFAULT 0,
    credit           NUMERIC(18, 2) NOT NULL DEFAULT 0,
    in_z             TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    out_z            TIMESTAMPTZ                 -- NULL = current record
);

-- Only one active version per natural key at a time.
CREATE UNIQUE INDEX IF NOT EXISTS uix_borrowings_active
    ON borrowings (transaction_date, voucher_no, account)
    WHERE out_z IS NULL;

-- Per-account statement query (Borrowings report, filtered by account and ordered by date).
CREATE INDEX IF NOT EXISTS idx_borrowings_account_date
    ON borrowings (account, transaction_date)
    WHERE out_z IS NULL;

-- Date-range query (Borrowings meta / list, current rows only).
CREATE INDEX IF NOT EXISTS idx_borrowings_date
    ON borrowings (transaction_date)
    WHERE out_z IS NULL;
