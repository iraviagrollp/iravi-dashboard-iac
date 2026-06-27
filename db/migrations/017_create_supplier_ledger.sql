-- Migration 017: create supplier_ledger table
-- Applied MANUALLY via psql over the SSM tunnel; NOT automatic.
-- Run AFTER terraform apply has provisioned lambda_etl_supplier_ledger.
--
-- supplier_ledger mirrors customer_ledger exactly (same shape, same
-- uni-temporal milestoning pattern) but is populated by the
-- etl_supplier_ledger Lambda from the "Ledger All Accounts" file,
-- filtering for supplier (creditor/payable) account rows.
--
-- natural key: (transaction_date, voucher_no, account_name, category, sub_category)
-- out_z IS NULL  → current (active) record
-- out_z IS NOT NULL → superseded; kept for audit history

CREATE TABLE supplier_ledger (
    id               SERIAL PRIMARY KEY,
    transaction_date DATE            NOT NULL,
    voucher_no       VARCHAR(50)     NOT NULL,
    account_name     VARCHAR(200)    NOT NULL,
    category         VARCHAR(10)     NOT NULL,
    sub_category     VARCHAR(100)    NOT NULL,
    amount           NUMERIC(15, 4)  NOT NULL,
    in_z             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    out_z            TIMESTAMPTZ                 -- NULL = current record
);

-- Only one active version per natural key at a time.
CREATE UNIQUE INDEX uix_supplier_ledger_active
    ON supplier_ledger (transaction_date, voucher_no, account_name, category, sub_category)
    WHERE out_z IS NULL;

CREATE INDEX idx_supplier_ledger_date    ON supplier_ledger (transaction_date);
CREATE INDEX idx_supplier_ledger_account ON supplier_ledger (account_name);
CREATE INDEX idx_supplier_ledger_out_z   ON supplier_ledger (out_z) WHERE out_z IS NULL;
