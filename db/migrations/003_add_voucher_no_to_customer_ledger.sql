-- Migration: 003_add_voucher_no_to_customer_ledger
-- Applied: (not yet applied)
--
-- Context: voucher_no was added to customer_ledger as part of the natural key.
-- The table was created without this column before any data was inserted, so
-- a straight NOT NULL column add is safe. The partial unique index must be
-- dropped and recreated to include voucher_no.

ALTER TABLE customer_ledger
    ADD COLUMN voucher_no VARCHAR(50) NOT NULL;

DROP INDEX uix_customer_ledger_active;

CREATE UNIQUE INDEX uix_customer_ledger_active
    ON customer_ledger (transaction_date, voucher_no, account_name, category, sub_category)
    WHERE out_z IS NULL;
