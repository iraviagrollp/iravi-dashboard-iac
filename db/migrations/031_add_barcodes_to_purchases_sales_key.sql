-- 031_add_barcodes_to_purchases_sales_key.sql
-- Widen the milestoning natural key of `purchases` and `sales` to include `barcodes`.
--
-- Root cause fixed: the natural key (purchase_date, voucher_no, branch, party, product)
-- does NOT uniquely identify a line item. A single voucher legitimately carries the same
-- product on multiple lines, one per batch/barcode lot. The close-then-insert ETL treated
-- each extra batch line as a newer version of the same row (last-writer-wins), silently
-- collapsing real rows (observed: 785 parsed -> 770 stored in one AppendixPurchaseReport).
--
-- Adding `barcodes` to the key separates the batch lines. `barcodes` is nullable, so the
-- index (and the matching ETL UPDATE predicate) use COALESCE(barcodes, '') to treat NULL
-- and '' as the same value and preserve the "one active version per key" guarantee — a
-- plain nullable column in a UNIQUE index would let multiple NULL-barcode rows stay active.
--
-- The new key is strictly finer than the old one, so no existing active row can violate the
-- new index; drop-and-recreate is safe. A re-ingest of the purchase/sale Appendix files is
-- required after deploy to backfill the previously-collapsed rows.

BEGIN;

DROP INDEX IF EXISTS uix_purchases_active;
CREATE UNIQUE INDEX uix_purchases_active
    ON purchases (purchase_date, voucher_no, branch, party, product, COALESCE(barcodes, ''))
    WHERE out_z IS NULL;

DROP INDEX IF EXISTS uix_sales_active;
CREATE UNIQUE INDEX uix_sales_active
    ON sales (purchase_date, voucher_no, branch, party, product, COALESCE(barcodes, ''))
    WHERE out_z IS NULL;

COMMIT;
