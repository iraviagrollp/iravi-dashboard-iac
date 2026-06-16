-- Migration 009: create RBAC tables (roles, screens, role→screen mappings, users)
-- Powers the dashboard access-control feature. Run once against the live RDS
-- instance via the bastion SSM port-forward.
--
-- password_hash holds a PBKDF2 composite string produced by the API Lambda
-- (business-core/lambda/api/auth.py): pbkdf2_sha256$<iterations>$<salt_b64>$<hash_b64>.
-- The bootstrap admin USER is created on first login (not seeded here) so no
-- password is ever hashed in SQL.

-- Roles the admin creates (e.g. "Purchase Viewer").
-- is_admin = TRUE grants every screen + the Access Control configuration screen.
CREATE TABLE app_roles (
    role_id     SERIAL PRIMARY KEY,
    role_name   VARCHAR(64)  NOT NULL,
    is_admin    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_app_roles_name UNIQUE (role_name)
);

-- Canonical list of mappable dashboard screens. Keys MUST match ui/src/screens.ts.
CREATE TABLE app_screens (
    screen_key  VARCHAR(64)  PRIMARY KEY,
    label       VARCHAR(128) NOT NULL,
    sort_order  INT          NOT NULL DEFAULT 0
);

-- Many-to-many: which screens each role may view.
CREATE TABLE app_role_screens (
    role_id     INT          NOT NULL REFERENCES app_roles(role_id)      ON DELETE CASCADE,
    screen_key  VARCHAR(64)  NOT NULL REFERENCES app_screens(screen_key) ON DELETE CASCADE,

    PRIMARY KEY (role_id, screen_key)
);

-- Dashboard login users. One role per user.
CREATE TABLE app_users (
    user_id       SERIAL PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL,
    password_hash TEXT         NOT NULL,
    role_id       INT          NOT NULL REFERENCES app_roles(role_id),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_app_users_username UNIQUE (username)
);

CREATE INDEX idx_app_users_role ON app_users (role_id);

-- Seed the canonical screens (keys mirror ui/src/screens.ts).
INSERT INTO app_screens (screen_key, label, sort_order) VALUES
    ('overview',                 'Overview',                 10),
    ('sales',                    'Sales',                    20),
    ('purchases',                'Purchases',                30),
    ('stocks',                   'Stocks',                   40),
    ('customers',                'Customer Ledger',          50),
    ('balances',                 'Customer Balances',        60),
    ('reports.appendix_b',       'Appendix B',               70),
    ('reports.ledger_statement', 'Customer Ledger (report)', 80);

-- Seed the built-in Administrator role. The admin USER is created on first login
-- from the BOOTSTRAP_ADMIN_USERNAME / BOOTSTRAP_ADMIN_PASSWORD Lambda env vars.
INSERT INTO app_roles (role_name, is_admin) VALUES ('Administrator', TRUE);
