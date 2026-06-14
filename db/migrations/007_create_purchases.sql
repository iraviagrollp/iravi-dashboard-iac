-- 007_create_purchases.sql
-- Line-item purchase ledger from FUSIL PRO "AppendixPurchaseReport" (purchase_return='N')
-- and "AppendixPurReturn" (purchase_return='Y') exports.
-- Natural key / PK: (purchase_date, voucher_no, branch, party, product).
-- Uni-temporal milestoning: in_z/out_z track versions; out_z IS NULL = current record.

CREATE TABLE purchases (
    id              SERIAL PRIMARY KEY,
    purchase_date   DATE            NOT NULL,
    voucher_no      VARCHAR(50)     NOT NULL,
    branch          VARCHAR(100)    NOT NULL,
    party           VARCHAR(200)    NOT NULL,
    ref_bill_no     VARCHAR(100),
    ref_bill_date   DATE,
    product         VARCHAR(300)    NOT NULL,
    qty             NUMERIC(15, 3),
    rate            NUMERIC(12, 4),
    gross           NUMERIC(15, 2),
    av              NUMERIC(15, 2),
    barcodes        TEXT,
    narration       TEXT,
    purchase_return VARCHAR(1)      NOT NULL,
    in_z            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    out_z           TIMESTAMPTZ,    -- NULL = current record

    CONSTRAINT chk_purchases_return CHECK (purchase_return IN ('Y', 'N'))
);

-- Enforce one active version per natural key at a time.
CREATE UNIQUE INDEX uix_purchases_active
    ON purchases (purchase_date, voucher_no, branch, party, product)
    WHERE out_z IS NULL;

CREATE INDEX idx_purchases_date  ON purchases (purchase_date);
CREATE INDEX idx_purchases_party ON purchases (party);
CREATE INDEX idx_purchases_out_z ON purchases (out_z) WHERE out_z IS NULL;
