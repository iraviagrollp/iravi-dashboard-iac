-- Migration: 002_repair_customer_ledger_duplicates
-- Applied: (not yet applied — run if duplicate active rows are ever found)
--
-- Context: if customer_ledger rows are ever inserted without the two-step
-- milestoning UPDATE+INSERT (e.g. a plain INSERT bypassing ETL logic), multiple
-- out_z IS NULL rows can accumulate for the same natural key, violating the
-- uix_customer_ledger_active partial unique index. This query closes all but the
-- latest active record per key.
--
-- Safe to re-run: the subquery returns NULL when there is only one active row,
-- so the WHERE condition never matches and no rows are updated.

UPDATE customer_ledger c
SET out_z = NOW()
WHERE out_z IS NULL
  AND in_z < (
      SELECT MAX(in_z)
      FROM customer_ledger c2
      WHERE c2.transaction_date = c.transaction_date
        AND c2.voucher_no       = c.voucher_no
        AND c2.account_name     = c.account_name
        AND c2.category         = c.category
        AND c2.sub_category     = c.sub_category
        AND c2.out_z IS NULL
  );
