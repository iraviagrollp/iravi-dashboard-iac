-- 006_create_appendix_b_x11_stock_ledger.sql
-- Purchase ledger from FUSIL PRO "AppendixPurchaseReport" export.
-- Natural key: (purchase_date, iravi_voucher, technical_name, barcode).
-- Uni-temporal milestoning: in_z/out_z track versions; out_z IS NULL = current record.
-- mdf_date and exp_date are looked up from appendix_b_x11_stock at ingest time.
-- in_out is always 'In' for purchase entries.

CREATE TABLE appendix_b_x11_stock_ledger (
    id                  SERIAL PRIMARY KEY,
    purchase_date       DATE            NOT NULL,
    iravi_voucher       VARCHAR(50)     NOT NULL,
    supplier_voucher    VARCHAR(200),
    branch              VARCHAR(100),
    party               VARCHAR(200),
    technical_name      VARCHAR(300)    NOT NULL,
    barcode             VARCHAR(100)    NOT NULL,
    mdf_date            DATE,
    exp_date            DATE,
    in_out              VARCHAR(10)     NOT NULL DEFAULT 'In',
    qty                 NUMERIC(15, 3),
    in_z                TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    out_z               TIMESTAMPTZ     -- NULL = current record
);

-- Enforce one active version per natural key at a time.
CREATE UNIQUE INDEX uix_appendix_b_x11_ledger_active
    ON appendix_b_x11_stock_ledger (purchase_date, iravi_voucher, technical_name, barcode)
    WHERE out_z IS NULL;

CREATE INDEX idx_appendix_b_x11_ledger_date    ON appendix_b_x11_stock_ledger (purchase_date);
CREATE INDEX idx_appendix_b_x11_ledger_barcode ON appendix_b_x11_stock_ledger (barcode);
CREATE INDEX idx_appendix_b_x11_ledger_out_z   ON appendix_b_x11_stock_ledger (out_z) WHERE out_z IS NULL;
