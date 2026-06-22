-- Widen customer_ledger.amount from NUMERIC(15,2) to NUMERIC(15,4).
-- The "Ledger All Accounts" export carries GST component lines at 3 decimal
-- places (e.g. 6498.675); storing at 2dp rounded them and produced a 1-paise
-- drift when components were summed per voucher in the ledger statement.
-- After applying this, RE-INGEST the ledger file(s) so existing rows regain
-- full precision (already-stored rows were truncated to 2dp and cannot be
-- recovered by the ALTER alone). Applied manually via psql over the SSM tunnel.
ALTER TABLE customer_ledger ALTER COLUMN amount TYPE NUMERIC(15,4);
