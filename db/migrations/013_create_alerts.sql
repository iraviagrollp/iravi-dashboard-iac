-- Migration 013: create admin-configurable balance alerts tables
-- Feature: Alerts — admin-defined rules that evaluate customer balances on a
-- schedule and email recipients when conditions are met.
--
-- APPLY MANUALLY via psql over the SSM tunnel:
--   aws ssm start-session \
--     --target $(terraform output -raw bastion_instance_id) \
--     --document-name AWS-StartPortForwardingSessionToRemoteHost \
--     --parameters '{"host":["<RDS_HOST>"],"portNumber":["5432"],"localPortNumber":["5432"]}'
--   # In a second terminal:
--   psql "host=127.0.0.1 port=5432 dbname=iravi_dashboard user=dashboard_admin" \
--     -f 013_create_alerts.sql
--
-- This migration is idempotent (uses IF NOT EXISTS). Safe to re-run.
-- DO NOT run automatically — always apply manually after merge to main.

-- ── alerts ────────────────────────────────────────────────────────────────────
-- One row per admin-configured alert rule.
-- frequency: daily | weekly | monthly
-- schedule_day: weekly → 0-6 (0=Mon); monthly → 1-28; daily → NULL
-- match_type: all (AND) | any (OR) across alert_conditions
CREATE TABLE IF NOT EXISTS alerts (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(120)  NOT NULL,
    category      VARCHAR(40)   NOT NULL DEFAULT 'balances',
    frequency     VARCHAR(10)   NOT NULL,
    schedule_day  SMALLINT,
    match_type    VARCHAR(3)    NOT NULL DEFAULT 'all',
    is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
    created_by    VARCHAR(64),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_alerts_frequency   CHECK (frequency  IN ('daily', 'weekly', 'monthly')),
    CONSTRAINT chk_alerts_match_type  CHECK (match_type IN ('all', 'any')),
    CONSTRAINT chk_alerts_schedule_day CHECK (
        (frequency = 'daily'   AND schedule_day IS NULL)
     OR (frequency = 'weekly'  AND schedule_day BETWEEN 0 AND 6)
     OR (frequency = 'monthly' AND schedule_day BETWEEN 1 AND 28)
    )
);

-- ── alert_conditions ──────────────────────────────────────────────────────────
-- One or more filter conditions per alert.
-- op: gt | gte | lt | lte | eq | between
-- value2 is only populated for op = 'between'.
CREATE TABLE IF NOT EXISTS alert_conditions (
    id        SERIAL PRIMARY KEY,
    alert_id  INT           NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
    field     VARCHAR(40)   NOT NULL,
    op        VARCHAR(10)   NOT NULL,
    value     NUMERIC(15,2) NOT NULL,
    value2    NUMERIC(15,2),

    CONSTRAINT chk_alert_conditions_op CHECK (op IN ('gt', 'gte', 'lt', 'lte', 'eq', 'between'))
);

CREATE INDEX IF NOT EXISTS idx_alert_conditions_alert ON alert_conditions(alert_id);

-- ── alert_recipients ──────────────────────────────────────────────────────────
-- Email addresses (or future channels) that receive the alert email.
CREATE TABLE IF NOT EXISTS alert_recipients (
    id        SERIAL PRIMARY KEY,
    alert_id  INT           NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
    channel   VARCHAR(10)   NOT NULL DEFAULT 'email',
    address   VARCHAR(200)  NOT NULL,

    CONSTRAINT chk_alert_recipients_channel CHECK (channel IN ('email'))
);

CREATE INDEX IF NOT EXISTS idx_alert_recipients_alert ON alert_recipients(alert_id);

-- ── alert_runs ────────────────────────────────────────────────────────────────
-- Audit log of every evaluator invocation per alert.
-- status: success | failed | no_match
CREATE TABLE IF NOT EXISTS alert_runs (
    id        SERIAL PRIMARY KEY,
    alert_id  INT           REFERENCES alerts(id) ON DELETE CASCADE,
    run_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    matched   INT,
    status    VARCHAR(20),
    error     TEXT
);

CREATE INDEX IF NOT EXISTS idx_alert_runs_alert ON alert_runs(alert_id);
