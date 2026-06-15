-- 008_create_sales.sql
-- Line-item sales ledger from FUSIL PRO "AppendixSale" (sales_return='N')
-- and "AppendixRetSales" (sales_return='Y') exports.
-- Natural key / PK: (purchase_date, voucher_no, branch, party, product).
-- Uni-temporal milestoning: in_z/out_z track versions; out_z IS NULL = current record.

CREATE TABLE sales (
    id            SERIAL PRIMARY KEY,
    purchase_date DATE            NOT NULL,
    voucher_no    VARCHAR(50)     NOT NULL,
    branch        VARCHAR(100)    NOT NULL,
    party         VARCHAR(200)    NOT NULL,
    ref_bill_no   VARCHAR(100),
    ref_bill_date DATE,
    product       VARCHAR(300)    NOT NULL,
    qty           NUMERIC(15, 3),
    rate          NUMERIC(12, 4),
    gross         NUMERIC(15, 2),
    av            NUMERIC(15, 2),
    barcodes      TEXT,
    narration     TEXT,
    sales_return  VARCHAR(1)      NOT NULL,
    in_z          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    out_z         TIMESTAMPTZ,    -- NULL = current record

    CONSTRAINT chk_sales_return CHECK (sales_return IN ('Y', 'N'))
);

-- Enforce one active version per natural key at a time.
CREATE UNIQUE INDEX uix_sales_active
    ON sales (purchase_date, voucher_no, branch, party, product)
    WHERE out_z IS NULL;

CREATE INDEX idx_sale_date  ON sales (purchase_date);
CREATE INDEX idx_sale_party ON sales (party);
CREATE INDEX idx_sale_out_z ON sales (out_z) WHERE out_z IS NULL;
