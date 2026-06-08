-- Migration 004: create customer_details table
-- Run once against the live RDS instance via bastion SSM port-forward.

CREATE TABLE customer_details (
    id              SERIAL PRIMARY KEY,
    customer_name   VARCHAR(200)    NOT NULL,
    district        VARCHAR(100),
    city            VARCHAR(100),
    state           CHAR(2),
    pin             VARCHAR(10),
    mobile_no       VARCHAR(20),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_customer_details_name UNIQUE (customer_name)
);
