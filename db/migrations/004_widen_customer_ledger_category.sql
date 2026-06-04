-- Migration: 004_widen_customer_ledger_category
-- Applied: (not yet applied)
--
-- Context: 'Sales Return' (12 chars) exceeds the original VARCHAR(10) limit.
-- Widening to VARCHAR(20) to accommodate all category values.

ALTER TABLE customer_ledger
    ALTER COLUMN category TYPE VARCHAR(20);
