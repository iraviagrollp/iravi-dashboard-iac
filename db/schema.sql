-- ============================================================
-- IRAVI AGRO LIFE LLP - Admin Dashboard
-- Dashboard DB Schema
-- Target: Amazon RDS PostgreSQL
-- ============================================================


-- ============================================================
-- DIMENSIONS
-- ============================================================

CREATE TABLE dim_customers (
    id                  SERIAL PRIMARY KEY,
    customer_name       VARCHAR(200)    NOT NULL,
    customer_code       VARCHAR(20),
    parent_group        VARCHAR(100),
    contact_person      VARCHAR(200),
    gstn                VARCHAR(20),
    gst_reg_type        VARCHAR(50),
    city                VARCHAR(100),
    state               VARCHAR(100),
    pin                 VARCHAR(10),
    mobile_no           VARCHAR(15),
    alt_mobile_no       VARCHAR(15),
    email               VARCHAR(150),
    pan                 VARCHAR(15),
    licence_no          VARCHAR(50),
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_customers_name UNIQUE (customer_name)
);

CREATE INDEX idx_customers_code ON dim_customers (customer_code);
CREATE INDEX idx_customers_city ON dim_customers (city);


-- ============================================================
-- TRANSACTION FACT TABLES
-- Append daily. Upsert on natural business key to stay idempotent.
-- ============================================================

CREATE TABLE fact_sales (
    id                  SERIAL PRIMARY KEY,
    transaction_date    DATE            NOT NULL,
    voucher_no          VARCHAR(50)     NOT NULL,
    branch              VARCHAR(100),
    party_name          VARCHAR(200),
    party_gstn          VARCHAR(20),
    qty                 NUMERIC(12, 3),
    gross               NUMERIC(15, 2),
    discount            NUMERIC(15, 2),
    assessable_value    NUMERIC(15, 2),
    cgst                NUMERIC(15, 2),
    sgst                NUMERIC(15, 2),
    igst                NUMERIC(15, 2),
    net                 NUMERIC(15, 2),
    bill_value          NUMERIC(15, 2),
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_sales UNIQUE (voucher_no, transaction_date)
);

CREATE INDEX idx_sales_date   ON fact_sales (transaction_date);
CREATE INDEX idx_sales_branch ON fact_sales (branch);
CREATE INDEX idx_sales_party  ON fact_sales (party_name);


CREATE TABLE fact_sales_returns (
    id                  SERIAL PRIMARY KEY,
    transaction_date    DATE            NOT NULL,
    voucher_no          VARCHAR(50)     NOT NULL,
    branch              VARCHAR(100),
    location            VARCHAR(100),
    storage_bin         VARCHAR(150),
    party_name          VARCHAR(200),
    party_gstn          VARCHAR(20),
    ref_bill_no         VARCHAR(100),
    ref_bill_date       DATE,
    qty                 NUMERIC(12, 3),
    gross               NUMERIC(15, 2),
    discount            NUMERIC(15, 2),
    mrp_amount          NUMERIC(15, 2),
    gmd                 NUMERIC(15, 2),
    assessable_value    NUMERIC(15, 2),
    cgst                NUMERIC(15, 2),
    sgst                NUMERIC(15, 2),
    igst                NUMERIC(15, 2),
    net                 NUMERIC(15, 2),
    charges             NUMERIC(15, 2),
    charges_cgst        NUMERIC(15, 2),
    charges_sgst        NUMERIC(15, 2),
    charges_igst        NUMERIC(15, 2),
    deductions          NUMERIC(15, 2),
    adjustments         NUMERIC(15, 2),
    roundoff            NUMERIC(10,  2),
    bill_value          NUMERIC(15, 2),
    remarks             TEXT,
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_sales_returns UNIQUE (voucher_no, transaction_date)
);

CREATE INDEX idx_sales_returns_date  ON fact_sales_returns (transaction_date);
CREATE INDEX idx_sales_returns_party ON fact_sales_returns (party_name);


CREATE TABLE fact_purchases (
    id                  SERIAL PRIMARY KEY,
    transaction_date    DATE            NOT NULL,
    voucher_no          VARCHAR(50)     NOT NULL,
    branch              VARCHAR(100),
    party_name          VARCHAR(200),
    party_gstn          VARCHAR(20),
    ref_bill_date       DATE,
    qty                 NUMERIC(12, 3),
    gross               NUMERIC(15, 2),
    cgst                NUMERIC(15, 2),
    sgst                NUMERIC(15, 2),
    igst                NUMERIC(15, 2),
    net                 NUMERIC(15, 2),
    charges             NUMERIC(15, 2),
    charges_cgst        NUMERIC(15, 2),
    charges_sgst        NUMERIC(15, 2),
    charges_igst        NUMERIC(15, 2),
    roundoff            NUMERIC(10,  2),
    bill_value          NUMERIC(15, 2),
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_purchases UNIQUE (voucher_no, transaction_date)
);

CREATE INDEX idx_purchases_date   ON fact_purchases (transaction_date);
CREATE INDEX idx_purchases_branch ON fact_purchases (branch);
CREATE INDEX idx_purchases_party  ON fact_purchases (party_name);


-- Purchase returns are line-item level (one row per product per return voucher).
-- Unique key includes product_name because the same voucher covers multiple products.
CREATE TABLE fact_purchase_returns (
    id                  SERIAL PRIMARY KEY,
    transaction_date    DATE            NOT NULL,
    voucher_no          VARCHAR(50)     NOT NULL,
    branch              VARCHAR(100),
    party_name          VARCHAR(200),
    ref_bill_date       DATE,
    product_name        VARCHAR(300),
    qty                 NUMERIC(12, 3),
    rate                NUMERIC(12, 4),
    gross               NUMERIC(15, 2),
    disc_rate           NUMERIC(8,  4),
    discount            NUMERIC(15, 2),
    mrp                 NUMERIC(15, 2),
    gmd                 NUMERIC(15, 2),
    assessable_value    NUMERIC(15, 2),
    cgst_rate           NUMERIC(8,  4),
    cgst                NUMERIC(15, 2),
    sgst_rate           NUMERIC(8,  4),
    sgst                NUMERIC(15, 2),
    igst_rate           NUMERIC(8,  4),
    igst                NUMERIC(15, 2),
    net                 NUMERIC(15, 2),
    barcodes            TEXT,
    narration           TEXT,
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_purchase_returns UNIQUE (voucher_no, transaction_date, product_name)
);

CREATE INDEX idx_purchase_returns_date    ON fact_purchase_returns (transaction_date);
CREATE INDEX idx_purchase_returns_product ON fact_purchase_returns (product_name);


-- Modelled after Purchase Book. Will be adjusted once the Expenses file is available,
-- as it may carry a category/account head column that Purchase Book does not.
CREATE TABLE fact_expenses (
    id                  SERIAL PRIMARY KEY,
    transaction_date    DATE            NOT NULL,
    voucher_no          VARCHAR(50)     NOT NULL,
    branch              VARCHAR(100),
    party_name          VARCHAR(200),
    party_gstn          VARCHAR(20),
    ref_bill_date       DATE,
    qty                 NUMERIC(12, 3),
    gross               NUMERIC(15, 2),
    cgst                NUMERIC(15, 2),
    sgst                NUMERIC(15, 2),
    igst                NUMERIC(15, 2),
    net                 NUMERIC(15, 2),
    charges             NUMERIC(15, 2),
    charges_cgst        NUMERIC(15, 2),
    charges_sgst        NUMERIC(15, 2),
    charges_igst        NUMERIC(15, 2),
    roundoff            NUMERIC(10,  2),
    bill_value          NUMERIC(15, 2),
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_expenses UNIQUE (voucher_no, transaction_date)
);

CREATE INDEX idx_expenses_date   ON fact_expenses (transaction_date);
CREATE INDEX idx_expenses_branch ON fact_expenses (branch);


-- ============================================================
-- SNAPSHOT TABLES
-- Full replace per snapshot_date on each daily run.
-- ============================================================

-- Packing formats are shared across many products and snapshots.
-- Normalised here to avoid string duplication and enable pack-size filtering.
-- ETL inserts new packings on first encounter (INSERT ... ON CONFLICT DO NOTHING).
CREATE TABLE dim_packings (
    id                      SERIAL PRIMARY KEY,
    packing_description     VARCHAR(100)    NOT NULL,
    ingested_at             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_packings UNIQUE (packing_description)
);


-- Stocks sheet from Stocks.xlsx.
-- ETL forward-fills product_brand_name and s_no down packing sub-rows before inserting.
-- product_chemical_name is populated where the sub-row carries the chemical description.
CREATE TABLE snapshot_stock (
    id                      SERIAL PRIMARY KEY,
    snapshot_date           DATE            NOT NULL,
    s_no                    INTEGER,
    product_brand_name      VARCHAR(200)    NOT NULL,
    product_chemical_name   TEXT,
    packing_id              INTEGER         NOT NULL REFERENCES dim_packings(id),
    qty_ap_current          NUMERIC(12, 3),
    qty_ts_current          NUMERIC(12, 3),
    qty_ap_previous         NUMERIC(12, 3),
    qty_ts_previous         NUMERIC(12, 3),
    total_qty_current       NUMERIC(12, 3),
    total_qty_previous      NUMERIC(12, 3),
    rate                    NUMERIC(12, 4),
    opening_value           NUMERIC(15, 2),
    closing_value           NUMERIC(15, 2),
    ingested_at             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_stock UNIQUE (snapshot_date, product_brand_name, packing_id)
);

CREATE INDEX idx_stock_date    ON snapshot_stock (snapshot_date);
CREATE INDEX idx_stock_product ON snapshot_stock (product_brand_name);


-- Margin 03-04 sheet from Stocks.xlsx.
CREATE TABLE snapshot_stock_margin (
    id                  SERIAL PRIMARY KEY,
    snapshot_date       DATE            NOT NULL,
    product_brand_name  VARCHAR(200)    NOT NULL,
    packing_id          INTEGER         NOT NULL REFERENCES dim_packings(id),
    cost_price          NUMERIC(12, 4),
    margin_pct          NUMERIC(8,  4),
    nrv_price           NUMERIC(12, 4),
    nrv                 NUMERIC(15, 2),
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_stock_margin UNIQUE (snapshot_date, product_brand_name, packing_id)
);

CREATE INDEX idx_stock_margin_date ON snapshot_stock_margin (snapshot_date);


-- Customer Balances file. One row per branch x customer.
-- balance_type: 'Dr' = customer owes (receivable), 'Cr' = business owes customer.
CREATE TABLE snapshot_customer_balances (
    id                  SERIAL PRIMARY KEY,
    snapshot_date       DATE            NOT NULL,
    branch              VARCHAR(100)    NOT NULL,
    customer_name       VARCHAR(200)    NOT NULL,
    customer_code       VARCHAR(20),
    city                VARCHAR(100),
    debit               NUMERIC(15, 2),
    credit              NUMERIC(15, 2),
    balance_amount      NUMERIC(15, 2),
    balance_type        VARCHAR(2)      NOT NULL,
    ingested_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_customer_balances UNIQUE (snapshot_date, branch, customer_name),
    CONSTRAINT chk_balance_type CHECK (balance_type IN ('Dr', 'Cr'))
);

CREATE INDEX idx_customer_balances_date     ON snapshot_customer_balances (snapshot_date);
CREATE INDEX idx_customer_balances_customer ON snapshot_customer_balances (customer_name);
CREATE INDEX idx_customer_balances_branch   ON snapshot_customer_balances (branch);


-- ============================================================
-- ETL AUDIT
-- Tracks every pipeline run for alerting and replay purposes.
-- ============================================================

CREATE TABLE etl_runs (
    id              SERIAL PRIMARY KEY,
    run_date        DATE            NOT NULL,
    started_at      TIMESTAMPTZ     NOT NULL,
    completed_at    TIMESTAMPTZ,
    status          VARCHAR(20)     NOT NULL,
    files_processed JSONB,
    error_message   TEXT,

    CONSTRAINT uq_etl_runs   UNIQUE (run_date),
    CONSTRAINT chk_etl_status CHECK (status IN ('running', 'success', 'failed'))
);
