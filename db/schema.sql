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
-- snapshot_stock: uni-temporal milestoned (in_z/out_z) — see table comment.
-- snapshot_stock_margin, snapshot_customer_balances: full replace per snapshot_date.
-- ============================================================

-- Used by snapshot_stock_margin only. snapshot_stock no longer normalises packings —
-- packing is stored as (packing_size, packing_configuration) columns directly.
CREATE TABLE dim_packings (
    id                      SERIAL PRIMARY KEY,
    packing_description     VARCHAR(100)    NOT NULL,
    ingested_at             TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_packings UNIQUE (packing_description)
);


-- Processed stock output (from etl_stocks Lambda / process.py _OUTPUT_HEADERS).
-- Natural key: (brand, technical, packing_size, packing_configuration,
--               branch, special_packing_mention, entry_date).
-- Uni-temporal milestoning: in_z/out_z track versions of the same natural key.
--   out_z IS NULL  → current (active) record.
--   out_z IS NOT NULL → superseded; kept for audit history.
-- When a re-run delivers the same entry_date, the old row is closed (out_z = NOW())
-- and a fresh row is inserted (in_z = NOW(), out_z = NULL).
CREATE TABLE snapshot_stock (
    id                      SERIAL PRIMARY KEY,
    brand                   VARCHAR(200)    NOT NULL,
    technical               VARCHAR(300)    NOT NULL,
    packing_size            NUMERIC(12, 4)  NOT NULL,   -- base unit: grams or ml
    packing_configuration   VARCHAR(10)     NOT NULL,   -- 'gms' or 'ml'
    available_nos           NUMERIC(12, 3)  NOT NULL,
    conversion_factor       NUMERIC(12, 4),
    available_cases         NUMERIC(12, 4),
    available_qty           NUMERIC(15, 2),             -- packing_size × available_nos
    branch                  VARCHAR(100)    NOT NULL,
    special_packing_mention VARCHAR(100)    NOT NULL DEFAULT 'NA',
    entry_date              DATE            NOT NULL,
    rate                    NUMERIC(12, 4),             -- purchase price; NULL when rates file absent
    stock_valuation         NUMERIC(15, 2),             -- available_nos × rate; NULL when rate NULL
    in_z                    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    out_z                   TIMESTAMPTZ                 -- NULL = current record
);

-- Only one active version per natural key at a time.
CREATE UNIQUE INDEX uix_stock_active
    ON snapshot_stock (brand, technical, packing_size, packing_configuration,
                       branch, special_packing_mention, entry_date)
    WHERE out_z IS NULL;

CREATE INDEX idx_stock_entry_date ON snapshot_stock (entry_date);
CREATE INDEX idx_stock_brand      ON snapshot_stock (brand);
CREATE INDEX idx_stock_branch     ON snapshot_stock (branch);
CREATE INDEX idx_stock_out_z      ON snapshot_stock (out_z) WHERE out_z IS NULL;


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


-- Customer Accounts Export File. One row per transaction entry.
-- Natural key: (transaction_date, account_name, category, sub_category).
-- Uni-temporal milestoning: in_z/out_z track versions of the same natural key.
--   out_z IS NULL  → current (active) record.
--   out_z IS NOT NULL → superseded; kept for audit history.
-- category: 'Cr' = credit entry, 'Db' = debit entry.
CREATE TABLE customer_ledger (
    id              SERIAL PRIMARY KEY,
    transaction_date DATE           NOT NULL,
    account_name    VARCHAR(200)    NOT NULL,
    category        VARCHAR(10)     NOT NULL,
    sub_category    VARCHAR(100)    NOT NULL,
    amount          NUMERIC(15, 2)  NOT NULL,
    in_z            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    out_z           TIMESTAMPTZ                 -- NULL = current record
);

-- Only one active version per natural key at a time.
CREATE UNIQUE INDEX uix_customer_ledger_active
    ON customer_ledger (transaction_date, account_name, category, sub_category)
    WHERE out_z IS NULL;

CREATE INDEX idx_customer_ledger_date    ON customer_ledger (transaction_date);
CREATE INDEX idx_customer_ledger_account ON customer_ledger (account_name);
CREATE INDEX idx_customer_ledger_out_z   ON customer_ledger (out_z) WHERE out_z IS NULL;


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
