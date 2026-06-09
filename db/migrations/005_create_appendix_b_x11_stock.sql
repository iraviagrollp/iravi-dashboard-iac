-- 005_create_appendix_b_x11_stock.sql
-- Barcodes master data from FUSIL PRO "Barcodes Masters" export.
-- Natural key: (barcode, technical_name, vendor).
-- Uni-temporal milestoning: in_z/out_z track versions; out_z IS NULL = current record.

CREATE TABLE appendix_b_x11_stock (
    id              SERIAL PRIMARY KEY,
    barcode         VARCHAR(100)    NOT NULL,
    technical_name  VARCHAR(300)    NOT NULL,
    vendor          VARCHAR(200)    NOT NULL,
    mdf_date        DATE,
    exp_date        DATE,
    in_z            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    out_z           TIMESTAMPTZ     -- NULL = current record
);

-- Enforce one active version per natural key at a time.
CREATE UNIQUE INDEX uix_appendix_b_x11_active
    ON appendix_b_x11_stock (barcode, technical_name, vendor)
    WHERE out_z IS NULL;

CREATE INDEX idx_appendix_b_x11_barcode ON appendix_b_x11_stock (barcode);
CREATE INDEX idx_appendix_b_x11_out_z   ON appendix_b_x11_stock (out_z) WHERE out_z IS NULL;
