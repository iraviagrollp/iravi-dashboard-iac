# IRAVI AGRO LIFE LLP — Admin Dashboard Infrastructure

Terraform-managed AWS infrastructure for the Admin Dashboard project.
Region: `ap-south-1` (Mumbai).

---

## What This Provisions

| Layer | Resource |
|---|---|
| Network | VPC, 2 public + 2 private subnets, Internet Gateway, NAT Gateway |
| Security | 5 security groups (Lambda, RDS, ElastiCache, VPC Endpoints, Bastion) with scoped rules |
| VPC Endpoints | S3 gateway (free), Secrets Manager interface (dedicated endpoint SG) |
| Database | RDS PostgreSQL 16 — `db.t3.small`, 20 GB gp3, encrypted |
| Credentials | AWS Secrets Manager secret with DB host/port/name/user/password |
| Monitoring | SNS alert topic + 5 CloudWatch alarms (CPU, storage, connections, memory, write latency) |
| Bastion Host | `t3.micro` EC2 in public subnet — SSM Session Manager port forwarding to RDS (no SSH, no key pair) |
| SES | Domain identity + DKIM for `iraviagrolife.com`; configuration set `iravi-dashboard-alerts`; used by alerts_evaluator Lambda; DNS records output by `terraform output ses_dkim_tokens` |
| Alerts Evaluator Lambda | `iravi-dashboard-alerts-evaluator` — Python 3.12, 256 MB, 300 s; layers: `api_deps` (psycopg2, shared) + `alerts_evaluator_deps` (reportlab — Monthly Sales PDF attachments); EventBridge `rate(15 minutes)` — send time is per-alert (`alerts.schedule_time`, IST); Lambda self-selects which alerts are due each invocation |
| Alerts API routes | 6 admin-only routes in `api_rbac_routes`: `GET/POST /alerts`, `PUT/DELETE /alerts/{id}`, `GET /alerts/fields`, `POST /alerts/{id}/test` |
| Supplier Ledger Lambda | `iravi-dashboard-etl-supplier-ledger` — Python 3.12, 512 MB, 300 s, own layer (openpyxl/psycopg2); triggered by EventBridge "Object Created" rule on `raw/Ledger` prefix; read-only S3 IAM (GetObject + ListBucket, no Put/Delete); upserts `supplier_ledger` table with uni-temporal milestoning; `eventbridge = true` added to the shared S3 bucket notification to enable this flow |
| CI/CD | GitHub Actions — fmt + validate on PR (Stage 1); plan + apply coming after AWS account setup |
| Diagram (SVG) | `design/system-architecture-diagram.html` — dark-theme SVG across all four repos; Alerts subsystem added (cron, evaluator, SES, recipients); DB tables 013–014; API routes; git-ignored, local only |
| Diagram (HTML) | `design/combined-system-architecture.html` — AWS Reference Architecture style HTML; same Alerts additions + repo-card updates; git-ignored, local only |
| Setup Guide | AWS account setup guide — `design/aws-account-setup-guide.html` (git-ignored, local only) |
| Connection Guide | Bastion SSM port forwarding + schema runner guide — `design/bastion-rds-connection-guide.html` (git-ignored, local only) |

---

## Git Workflow

Never push directly to `main`. All changes go through a feature branch and PR.

```bash
# Start a new piece of work
git checkout -b feature/add-elasticache

# Make your changes, then push
git add terraform/environments/production/elasticache.tf
git commit -m "add ElastiCache Redis cluster"
git push origin feature/add-elasticache

# Open a PR on GitHub → pipeline runs automatically → review → merge
```

### What the pipeline checks on every PR

| Stage | Status | What it does | AWS needed? |
|---|---|---|---|
| Format | ✅ Active | `terraform fmt --check -diff` — fails and shows exact diff if files aren't formatted | No |
| Init | ✅ Active | `terraform init -backend=false` — verifies providers resolve | No |
| Validate | ✅ Active | `terraform validate` — catches syntax and config errors | No |
| Plan | ✅ Active | `terraform plan` — shows exactly what will change in AWS, posted as PR comment | Yes (OIDC) |

### What happens on merge to `main`

| Stage | Status | What it does | AWS needed? |
|---|---|---|---|
| Apply | ✅ Active | `terraform apply` — deploys changes to AWS automatically | Yes (OIDC) |

> Both commented-out stages are already written in `.github/workflows/terraform.yml` — they just need AWS credentials wired up and the comment blocks removed.

### Enabling branch protection on GitHub

Go to **GitHub repo → Settings → Branches → Add rule**:
- Branch name pattern: `main`
- ✅ Require a pull request before merging
- ✅ Require status checks to pass → select `Format & Validate`
- ✅ Do not allow bypassing the above settings

### Enabling Plan + Apply (when AWS account is ready)

**Step 1 — Run bootstrap** (creates S3 state bucket + DynamoDB lock):
```bash
cd terraform/bootstrap
terraform init
terraform apply
# Note the state_bucket_name output — paste it into environments/production/main.tf
```

**Step 2 — Create OIDC provider in AWS IAM**
- Console → IAM → Identity Providers → Add Provider
- Type: `OpenID Connect`
- URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

**Step 3 — Create IAM Role `terraform-deployer`**
- Trusted entity: Web identity → select the GitHub OIDC provider above
- Condition: `token.actions.githubusercontent.com:sub` = `repo:iraviagrollp/iravi-dashboard-iac:ref:refs/heads/main`
- Permissions: `AdministratorAccess` (can be narrowed later)

**Step 4 — Add secrets to GitHub**

Go to Repo → Settings → Secrets and variables → Actions → New repository secret. Add both:

| Secret name | Value | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | ARN of `terraform-deployer` role | Used by the pipeline OIDC step to assume the IAM role and authenticate with AWS |
| `TF_VAR_alert_email` | your email address | Terraform `alert_email` variable — SNS subscription for CloudWatch alarms |
| `TF_VAR_dashboard_username` | login username | Injected into Amplify as `VITE_DASHBOARD_USERNAME` at build time |
| `TF_VAR_dashboard_password` | login password | Injected into Amplify as `VITE_DASHBOARD_PASSWORD` at build time |

> **Why `TF_VAR_*` secrets?** `terraform.tfvars` is git-ignored so the pipeline can't read it. Terraform automatically maps any environment variable prefixed with `TF_VAR_` to the matching input variable — these secrets are the pipeline equivalent of `terraform.tfvars`.

**Step 5 — Uncomment Stage 2 in `.github/workflows/terraform.yml`**
- Remove the `#` comment block around the `plan` job
- Open a test PR — confirm the plan output appears as a PR comment

**Step 6 — Uncomment Stage 3 once Stage 2 is confirmed**
- Remove the `#` comment block around the `apply` job
- First apply provisions all ~27 resources (takes 8–12 minutes)

---

## Prerequisites

### Tools

| Tool | Min Version | Install |
|---|---|---|
| Terraform | 1.6+ | https://developer.hashicorp.com/terraform/install |
| AWS CLI | 2.x | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |

### AWS Account

You need an AWS account with programmatic access. Configure credentials before running anything:

```bash
aws configure
```

Enter when prompted:
- **AWS Access Key ID** — from IAM → Users → Security credentials
- **AWS Secret Access Key** — same place
- **Default region** — `ap-south-1`
- **Default output format** — `json`

Verify it works:

```bash
aws sts get-caller-identity
```

You should see your account ID and IAM user ARN.

---

## Directory Structure

```
IaC/
├── README.md
├── .gitignore
├── db/
│   ├── schema.sql                  ← PostgreSQL DDL — apply once on fresh DB
│   ├── schema.mmd                  ← Mermaid ER diagram
│   └── migrations/                 ← Numbered DML repair scripts — apply manually via psql
│       ├── 001_repair_snapshot_stock_duplicates.sql
│       ├── 002_repair_customer_ledger_duplicates.sql
│       ├── 003_add_voucher_no_to_customer_ledger.sql
│       ├── 004_create_customer_details.sql
│       ├── 005_create_appendix_b_x11_stock.sql
│       ├── 006_create_appendix_b_x11_stock_ledger.sql
│       ├── 007_create_purchases.sql
│       ├── 008_create_sales.sql
│       ├── 009_create_rbac.sql
│       ├── 010_add_customer_balances_fy_screen.sql
│       ├── 011_add_customer_code_to_customer_details.sql
│       ├── 012_widen_customer_ledger_amount.sql
│       ├── 013_create_alerts.sql                ← alerts/alert_conditions/alert_recipients/alert_runs
│       ├── 014_add_alert_schedule_time.sql      ← adds schedule_time TIME DEFAULT '11:00:00' to alerts
│       ├── 015_add_alert_branch.sql             ← adds nullable branch VARCHAR(100) to alerts (sales/sale_returns scope)
│       ├── 016_create_supplier_accounts.sql     ← creates supplier_accounts (uni-temporal milestoned, natural key: name)
│       ├── 017_create_supplier_ledger.sql       ← creates supplier_ledger (same shape as customer_ledger, uni-temporal milestoned)
│       ├── 018_add_supplier_balances_fy_screen.sql ← idempotent app_screens seed for 'reports.supplier_balances_fy' (NOT YET APPLIED)
│       └── 019_add_monthly_sales_screen.sql        ← idempotent app_screens seed for 'reports.monthly_sales' (NOT YET APPLIED)
└── terraform/
    ├── bootstrap/                  ← Run ONCE first — creates remote state storage
    │   └── main.tf
    └── environments/
        └── production/             ← All production infrastructure
            ├── main.tf             ← Provider + S3 backend config
            ├── variables.tf        ← All input variables
            ├── terraform.tfvars.example
            ├── outputs.tf
            ├── vpc.tf
            ├── security_groups.tf
            ├── vpc_endpoints.tf
            ├── rds.tf
            ├── secrets.tf
            ├── monitoring.tf
            ├── bastion.tf
            ├── elasticache.tf
            ├── lambda_etl_sales.tf          ← ETL sales Lambda + SHARED S3 bucket notification (fans out to all 11 Lambdas by prefix)
            ├── lambda_etl_supplier_accounts.tf  ← Supplier accounts ETL Lambda (trigger: raw/Supplier*.xlsx; own pip layer)
            ├── lambda_etl_stocks.tf         ← Stock balance ETL Lambda
            ├── lambda_etl_customer_ledger.tf← Customer ledger ETL Lambda (trigger: raw/Ledger*.xlsx)
            ├── lambda_etl_customer_accounts.tf ← Customer accounts ETL Lambda (trigger: raw/Customer*.xlsx)
            ├── lambda_etl_appendix_b_x11.tf ← Barcodes Masters ETL Lambda (trigger: raw/Barcodes*.xlsx)
            ├── lambda_etl_appendix_b_x11_purchase.tf        ← AppendixPurchaseReport ETL Lambda
            ├── lambda_etl_appendix_b_x11_purchase_return.tf ← AppendixPurReturn ETL Lambda
            ├── lambda_etl_appendix_b_x11_sale.tf            ← AppendixSale ETL Lambda
            ├── lambda_etl_appendix_b_x11_sale_return.tf     ← AppendixRetSales ETL Lambda
            ├── lambda_whatsapp_notifier.tf  ← WhatsApp notifier Lambda (trigger: notifications/pending/*)
            ├── lambda_redis_updater.tf      ← Redis updater + 3 EventBridge rules (stocks/ledger/sales success)
            ├── lambda_api.tf               ← API Lambda + API Gateway HTTP API + api_deps layer; RBAC /auth/* + /admin/* routes; alerts CRUD routes (admin-only); GET /reports/customer-balances-fy route; GET /reports/supplier-balances-fy route (migration 018); GET /reports/monthly-sales route (migration 019)
            ├── ses.tf                      ← SES domain identity + DKIM for alerts emails; outputs DNS records
            ├── lambda_alerts_evaluator.tf  ← Alerts Evaluator Lambda + EventBridge rate(15 min); layers: api_deps + alerts_evaluator_deps (reportlab); SES IAM covers domain + address-level identities (identity/*)
            └── amplify.tf                  ← Amplify app env vars (ONE-TIME import required — see Step 4a)
```

---

## Deployment Guide

### Step 1 — Bootstrap remote state (run once, ever)

Terraform needs an S3 bucket to store state and a DynamoDB table for locking.
This must be created before anything else.

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

When it completes, note the two output values:

```
state_bucket_name = "iravi-dashboard-tfstate-<your-account-id>"
state_lock_table  = "iravi-dashboard-tfstate-lock"
```

---

### Step 2 — Configure the backend

Open `terraform/environments/production/main.tf` and replace the placeholder in the backend block:

```hcl
backend "s3" {
  bucket         = "iravi-dashboard-tfstate-<your-account-id>"   # ← replace this
  key            = "infra/terraform.tfstate"
  region         = "ap-south-1"
  dynamodb_table = "iravi-dashboard-tfstate-lock"
  encrypt        = true
}
```

---

### Step 3 — Set your variables

```bash
cd terraform/environments/production
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` — the only required field is `alert_email`. The alerts/SES variables have defaults that match the production domain:

```hcl
aws_region   = "ap-south-1"
environment  = "production"
alert_email  = "your-email@example.com"   # ← CloudWatch alarm emails

# Alerts feature — SES sender identity (defaults are already correct for prod)
alerts_sender_email = "noreply@iraviagrolife.com"
alerts_domain       = "iraviagrolife.com"
```

> `terraform.tfvars` is git-ignored. Never commit it.

---

### Step 4a — Import the Amplify app (one-time, if app already exists)

`amplify.tf` manages env vars on the Amplify app that was connected to GitHub manually. Before the first `terraform apply`, import it so Terraform doesn't try to create a duplicate:

```bash
cd terraform/environments/production
terraform import aws_amplify_app.dashboard <AMPLIFY_APP_ID>
```

Find the App ID in the Amplify console URL — it looks like `d1a2b3c4e5f6g7`. Skip this step only if starting from a completely fresh AWS account with no existing Amplify app.

---

### Step 4 — Deploy infrastructure

```bash
# Still inside terraform/environments/production/

terraform init
terraform plan    # review the planned resources
terraform apply
```

`terraform apply` takes **8–12 minutes**, most of which is waiting for RDS to become available.

> **Expected resource count:** the base platform (VPC, RDS, Redis, S3, Secrets, bastion, VPC endpoints, monitoring) is ~30 resources. Each Lambda adds ~5 (function, IAM role, role policy, log group, invoke permission); the 10 Lambdas, 2 shared layers, 3 EventBridge rules, and Amplify bring the full plan to **~90+ resources**. Run `terraform plan` for the exact current count rather than relying on a fixed number.

When it completes, note the outputs — you will need them for later pipeline components:

```
vpc_id                = "vpc-xxxxxxxxxxxxxxxxx"
private_subnet_ids    = ["subnet-xxx", "subnet-yyy"]
sg_lambda_id          = "sg-xxxxxxxxxxxxxxxxx"   ← attach to all Lambda functions
sg_elasticache_id     = "sg-xxxxxxxxxxxxxxxxx"   ← attach to ElastiCache cluster
db_secret_arn         = "arn:aws:secretsmanager:..."
sns_alerts_arn        = "arn:aws:sns:..."
api_endpoint          = "https://xxxxxxxxxx.execute-api.ap-south-1.amazonaws.com"
amplify_default_domain = "https://main.xxxxxxxxxx.amplifyapp.com"
```

To retrieve outputs at any time:

```bash
terraform output
```

---

### Step 6 — Confirm the SNS alert subscription

AWS sends a confirmation email to `alert_email`. **Click the link in that email** — alerts won't fire until you confirm.

---

### Step 7 — Apply the database schema

Connect to RDS via the bastion using SSM port forwarding and run `schema.sql` with psql.

**1. Install the Session Manager plugin** (one-time):
```
https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
```

**2. Get the bastion instance ID:**
```bash
cd terraform/environments/production
terraform output bastion_instance_id
```

**3. Get the RDS endpoint and password:**
- Endpoint: AWS Console → RDS → `iravi-dashboard-db` → Endpoint
- Password: AWS Console → Secrets Manager → `iravi/dashboard/db` → Retrieve secret value

**4. Start the port-forwarding session (leave this terminal open):**
```bash
aws ssm start-session \
  --target <bastion_instance_id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<rds-endpoint>"],"portNumber":["5432"],"localPortNumber":["5432"]}'
```

**5. In a second terminal, apply the schema:**
```bash
psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin password='<password>' sslmode=require" -f db/schema.sql
```

You should see `CREATE TABLE`, `CREATE INDEX` etc. for each statement.

---

## Connecting to RDS with a SQL Client

RDS is in a private subnet with no public IP. Connect via SSM Session Manager port forwarding through the bastion — no SSH key or open port required.

### Before first connection (one-time setup)

**1. Install the AWS Session Manager plugin:**
```
https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
```

**2. Get the bastion instance ID:**
```bash
cd terraform/environments/production && terraform output bastion_instance_id
```

### Starting a port-forwarding session

Run this in a dedicated terminal and leave it open while you use your SQL client:

```bash
aws ssm start-session \
  --target <bastion_instance_id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<rds-endpoint>"],"portNumber":["5432"],"localPortNumber":["5432"]}'
```

Get the RDS endpoint from: AWS Console → RDS → `iravi-dashboard-db` → Endpoint

### Connecting via pgAdmin / DBeaver / TablePlus

With the port-forwarding session running, connect your SQL client to:

| Field | Value |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Database | `iravi_dashboard` |
| Username | `dashboard_admin` |
| Password | AWS Console → Secrets Manager → `iravi/dashboard/db` → Retrieve secret value |

No SSH tunnel settings needed — the SSM session already handles the forwarding.

---

## Applying Future Schema Changes

When a schema change is needed (e.g. adding a column to `fact_expenses`):

1. Update `db/schema.sql` with the change (use `ALTER TABLE`, not full DDL)
2. Start an SSM port-forwarding session (see "Connecting to RDS" above)
3. Run the updated SQL:

```bash
psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin password='<password>' sslmode=require" -f db/schema.sql
```

## Applying Migrations

One-off DML repairs live in `db/migrations/` as numbered files. They are **not run automatically** — apply them manually when needed:

```bash
psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin password='<password>' sslmode=require" -f db/migrations/001_repair_snapshot_stock_duplicates.sql
```

Each migration file includes a comment explaining what it fixes and when it was applied. Run migrations in order (001, 002, …). They are idempotent — safe to re-run.

**Migration 012 note — `customer_ledger.amount` precision (NUMERIC(15,2) → NUMERIC(15,4)):**
The "Ledger All Accounts" export carries GST component lines at 3 decimal places (e.g. 6498.675).
Storing them at 2dp rounded the value and produced a 1-paise drift when components were summed per voucher.
After applying migration 012 you MUST:
1. Re-ingest the ledger file(s) via the ETL Lambda — the ALTER alone cannot recover already-truncated rows.
2. Flush the Redis cache (`POST /admin/cache/flush`) so the API serves fresh data from RDS.

**Migration 013 — alerts tables:**
Creates `alerts`, `alert_conditions`, `alert_recipients`, `alert_runs` for the balance-alerts feature.
Apply after `terraform apply` has provisioned the `ses.tf` + `lambda_alerts_evaluator.tf` resources and
after DNS verification for SES is complete. Migration is idempotent (`IF NOT EXISTS`).

**Migration 014 — `alerts.schedule_time` (per-alert send time):**
Adds `schedule_time TIME NOT NULL DEFAULT '11:00:00'` to the `alerts` table. The default preserves
the previous 11:00 IST behaviour for existing rows. Apply after migration 013. The
`alerts_evaluator` Lambda now runs every 15 minutes (`rate(15 minutes)`) and self-selects which
alerts are due for the current window based on `schedule_time` — send-time logic lives in
business-core. Migration is idempotent (`IF NOT EXISTS`).

**Migration 015 — `alerts.branch` (branch-scoped sales alerts):**
Adds a nullable `branch VARCHAR(100)` column to the `alerts` table. Used by the new `sales` and
`sale_returns` alert categories to restrict evaluation to a specific branch. `NULL` or `'ALL'`
means all branches; the column is ignored for `balances`-category alerts. Apply after migration 014.
No IaC Lambda change is required — the branch-filter evaluation logic lives entirely in
business-core (`alerts_evaluator`), which redeploys on the next `terraform apply`. Migration is
idempotent (`IF NOT EXISTS`).

**Migration 016 — `supplier_accounts` table:**
Creates the `supplier_accounts` table for the supplier master pipeline. Uni-temporal milestoned
(BIGSERIAL PK, natural key `name`, `in_z`/`out_z`). Partial unique index
`uix_supplier_accounts_active` enforces one active row per supplier name (`WHERE out_z IS NULL`).
Apply AFTER `terraform apply` has provisioned `lambda_etl_supplier_accounts` and AFTER
business-core has pushed `lambda/etl_supplier_accounts/`. Apply over the SSM tunnel:
```bash
psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin password='<password>' sslmode=require" \
     -f db/migrations/016_create_supplier_accounts.sql
```

**Migration 018 — `app_screens` seed for Supplier Balances (FY):**
Idempotently inserts screen key `reports.supplier_balances_fy` (label "Supplier Balances (FY)",
sort_order 91) into `app_screens` using `ON CONFLICT (screen_key) DO NOTHING`. Mirrors migration
010 (Customer Balances FY). Apply AFTER `terraform apply` has provisioned the new
`aws_apigatewayv2_route.reports_supplier_balances_fy` route AND after business-core has deployed
the `GET /reports/supplier-balances-fy` handler. Apply over the SSM tunnel:
```bash
psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin password='<password>' sslmode=require" \
     -f db/migrations/018_add_supplier_balances_fy_screen.sql
```
After applying, an admin must map the `reports.supplier_balances_fy` screen to the appropriate
roles via the Access Control screen in the dashboard UI.

**Migration 019 — `app_screens` seed for Monthly Sales:**
Idempotently inserts screen key `reports.monthly_sales` (label "Monthly Sales", sort_order 92)
into `app_screens` using `ON CONFLICT (screen_key) DO NOTHING`. Mirrors migrations 010 and 018.
Apply AFTER `terraform apply` has provisioned the new `aws_apigatewayv2_route.reports_monthly_sales`
route AND after business-core has deployed the `GET /reports/monthly-sales` handler. Apply over
the SSM tunnel:
```bash
psql "host=localhost port=5432 dbname=iravi_dashboard user=dashboard_admin password='<password>' sslmode=require" \
     -f db/migrations/019_add_monthly_sales_screen.sql
```
After applying, an admin must map the `reports.monthly_sales` screen to the appropriate roles via
the Access Control screen in the dashboard UI.

---

## SES Setup (alerts email)

Two manual steps are required after the first `terraform apply` that includes `ses.tf`:

### Step 1 — Add DNS records for domain verification

```bash
cd terraform/environments/production
terraform output ses_domain_verification_token
terraform output ses_dkim_tokens
```

In your DNS provider (e.g. Route 53, GoDaddy, Cloudflare):

| Record type | Name | Value |
|---|---|---|
| TXT | `_amazonses.iraviagrolife.com` | value from `ses_domain_verification_token` |
| CNAME | `<token1>._domainkey.iraviagrolife.com` | `<token1>.dkim.amazonses.com` |
| CNAME | `<token2>._domainkey.iraviagrolife.com` | `<token2>.dkim.amazonses.com` |
| CNAME | `<token3>._domainkey.iraviagrolife.com` | `<token3>.dkim.amazonses.com` |

SES auto-verifies within hours (up to 72 h). Check status in AWS Console → SES → Verified identities.

### Step 2 — Request SES production access

New AWS accounts start in the SES sandbox: outbound email is limited to verified recipient addresses only.
To lift this restriction:

1. AWS Console → SES → Account dashboard → **Request production access**
2. Fill in the support case:
   - Use case: Transactional
   - Daily sending volume: e.g. < 1,000/day
   - Confirm CAN-SPAM / DPDP compliance
3. Approval takes 1–2 business days.

**While in sandbox:** add each alert recipient email as a verified identity in SES (Console → SES → Verified identities → Create identity → Email address) before testing alert delivery.

---

## Useful Commands

```bash
# Show all deployed resource outputs
terraform output

# Check what would change before applying
terraform plan

# Refresh state from actual AWS resources
terraform refresh

# Show current state of a specific resource
terraform state show aws_db_instance.main

# Destroy everything (requires deletion_protection to be disabled first)
terraform destroy
```

---

## Cost Estimate (ap-south-1)

| Resource | Monthly | Notes |
|---|---|---|
| RDS db.t3.small (single-AZ, 20 GB gp3) | ~$29 | Instance + storage |
| NAT Gateway (1 AZ) + data | ~$44 | Largest cost — see note |
| Secrets Manager Interface endpoint | ~$10 | |
| Bastion EC2 t3.micro | ~$10 | Drops to ~$4 if stopped when not in use |
| CloudWatch alarms + logs | ~$2 | |
| S3 (state bucket, exports) | <$1 | |
| **Total (bastion running 24/7)** | **~$95/mo** | |
| **Total (bastion stopped when idle)** | **~$89/mo** | Realistic day-to-day |

> **Bastion tip:** Stop the bastion from the AWS Console when you're not actively querying the DB — you only pay ~$3.50/mo for the idle EIP instead of ~$10 for a running instance. Restart takes seconds.
>
> The NAT Gateway remains the largest fixed cost. It can be reduced later by adding VPC endpoints for CloudWatch Logs and SNS (see Prospective Cost Optimisations below).

---

## Prospective Cost Optimisations

Parked decisions — do not act on these without explicit discussion. Revisit as usage grows.

| # | Change | Est. Saving | Trigger |
|---|---|---|---|
| 1 | **VPC endpoints for CloudWatch Logs + SNS** | ~$5–10/mo | When ETL log volume grows or NAT costs are noticeable. Two interface endpoints (~$16/mo) eliminate NAT traffic for Lambda logs and alert publishes. |
| 2 | **RDS Reserved Instance (1-year, no upfront)** | ~$8–9/mo | After 3–6 months of stable usage — confirm `db.t3.small` is the right size before committing. No code change; purchase via AWS console. |
| 3 | **Lambda Graviton (arm64)** | ~10–20% on Lambda compute | After all Lambda functions (ETL, Redis Updater, API) are created and stable. One-line change per function: `architectures = ["arm64"]`. Apply as a batch across all functions at once. |

---

## Troubleshooting

**`terraform init` fails with backend error**
→ Make sure you completed Step 1 (bootstrap) and updated the bucket name in `main.tf`.

**RDS creation times out**
→ RDS can take up to 15 minutes on first provision. Run `terraform apply` again — it will resume from where it left off.

**SSM port-forwarding session fails to start**
→ Confirm the bastion instance is running (AWS Console → EC2). Verify the IAM instance profile `iravi-dashboard-bastion-profile` is attached and has `AmazonSSMManagedInstanceCore`. The SSM agent may take 1–2 minutes after instance start to register.

**Lambda times out reaching Secrets Manager**
→ The Secrets Manager Interface endpoint requires its own SG (`sg-vpc-endpoints`) with an inbound 443 rule from `sg_lambda_id`. Verify the `vpc_endpoints` SG exists and its ingress rule references the Lambda SG.

**psql errors with `relation already exists`**
→ The schema was already applied. This is safe — re-running is idempotent for `CREATE TABLE IF NOT EXISTS`. If you used plain `CREATE TABLE`, wrap DDL statements with `IF NOT EXISTS`.

**SNS email not arriving**
→ Check your spam folder. The sender is `no-reply@sns.amazonaws.com`. Subscription stays in `PendingConfirmation` state until confirmed.

**`terraform apply` tries to create a second Amplify app**
→ The Amplify app was connected to GitHub manually. Run `terraform import aws_amplify_app.dashboard <APP_ID>` before applying (see Step 4a). Find the App ID in the Amplify console URL.

**Amplify build fails with missing env vars**
→ Confirm `TF_VAR_dashboard_username` and `TF_VAR_dashboard_password` GitHub Actions secrets are set. After adding them, re-run `terraform apply` — Amplify env vars are only pushed on apply, not automatically.

**Alerts evaluator Lambda errors with `AccessDenied` on `ses:SendEmail`**
→ The Lambda IAM policy's SES `Resource` only covered the domain identity ARN (`identity/iraviagrolife.com`). When the From address is an address-level verified identity (e.g. `kranthi@iraviagrolife.com`), SES authorises against `identity/kranthi@iraviagrolife.com` — a different ARN — so the request is denied. The fix (applied 2026-06-25) broadens `Resource` to a two-element list: the domain identity ARN and `arn:aws:ses:<region>:<account>:identity/*`, covering any verified address under the account. Requires an IaC apply to take effect; as a stopgap the role policy can be edited manually in IAM console, but apply will reconcile it.

**Alerts evaluator Lambda errors with `MessageRejected` from SES**
→ The SES domain identity is not yet verified, or the account is still in sandbox mode. Check SES Console → Verified identities for the domain status. If status is `Pending`, the DNS records (Step 1 of SES setup above) have not propagated yet. If the domain is verified but the recipient is not, you are in sandbox — add the recipient as a verified identity or request production access.

**`terraform validate` fails with missing alerts_evaluator source**
→ The Lambda source directory `../business-core/lambda/alerts_evaluator/` does not exist yet. Push the business-core `alerts_evaluator` Lambda source before opening a PR against this IaC repo (Terraform reads the source path at validate time, not just at apply time).

**`terraform validate` fails with missing etl_supplier_accounts source**
→ The Lambda source directory `../business-core/lambda/etl_supplier_accounts/` does not exist yet. business-core must be pushed first — Terraform evaluates `archive_file` source paths at validate time.
