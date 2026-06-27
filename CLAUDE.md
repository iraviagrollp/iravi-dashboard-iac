# IRAVI AGRO LIFE LLP — Admin Dashboard

## Instructions for Claude

- After every conversation where decisions are made, code is written, or plans change — update this file to reflect the current state.
- Keep the **What Is Built** checklist accurate: tick items as they are completed.
- Keep the **What Is Next** section current: remove completed items, add newly discovered tasks.
- If a technical decision changes (schema, infra, architecture), update the relevant section here immediately.
- This file is the single source of truth for project state across sessions — treat it as such.
- **After every code change** — no matter how small — update both this file and `README.md` before closing the task:
  - CLAUDE.md: reflect any architectural decisions, new resources, security rules, or design constraints introduced by the change
  - README.md: update "What This Provisions", expected resource counts, troubleshooting entries, or deployment steps affected by the change
  - Never consider a task complete until both files are consistent with the current state of the code
- **Cross-project sync rule:** This file tracks high-level completion of ALL components (IaC, FileSyncAgent, ETL Lambda, API, UI). Each component has its own CLAUDE.md with detailed status. When a component reaches a milestone, tick the checkbox here. Do NOT duplicate implementation detail — just reflect done/in-progress/not-started.
  - FileSyncAgent detail → `D:\Projects\Iravi\FileSyncAgent\CLAUDE.md`

---

## Project Overview

Building an administration and monitoring dashboard for IRAVI AGRO LIFE LLP.
The business runs its transactional operations through **FUSIL PRO** (external .NET ERP)
backed by **IRAVI DB** (MySQL). This dashboard is a read-only analytics layer on top of it.

**Business goals:**
- Data driven development
- Transparency into finances
- Eyesight view of current business position for stakeholders

---

## Repository Layout

```
D:\Projects\Iravi\
├── IaC\                                ← this repo (Terraform + docs)
│   ├── CLAUDE.md                       ← this file
│   ├── README.md                       ← deployment runbook
│   ├── .gitignore
│   ├── db/
│   │   ├── schema.sql                  ← PostgreSQL DDL (FINALIZED)
│   │   ├── schema.mmd                  ← Mermaid class diagram of schema
│   │   └── migrations/                 ← numbered DML repair/migration scripts (run manually via psql)
│   │       ├── 001_repair_snapshot_stock_duplicates.sql
│   │       ├── 002_repair_customer_ledger_duplicates.sql
│   │       ├── 003_add_voucher_no_to_customer_ledger.sql
│   │       ├── 004_create_customer_details.sql
│   │       ├── 005_create_appendix_b_x11_stock.sql
│   │       ├── 006_create_appendix_b_x11_stock_ledger.sql
│   │       ├── 007_create_purchases.sql
│   │       ├── 008_create_sales.sql
│   │       ├── 009_create_rbac.sql
│   │       ├── 010_add_customer_balances_fy_screen.sql
│   │       └── 018_add_supplier_balances_fy_screen.sql
│   ├── design/                               ← git-ignored (local only)
│   │   ├── stakeholder-presentation.html
│   │   ├── system-architecture-diagram.html  ← dark SVG, full four-repo diagram (updated 2026-06-25: alerts, SES, mig 013-014, new API routes)
│   │   ├── combined-system-architecture.html ← HTML ref-arch style, same content (updated 2026-06-25)
│   │   ├── aws-architecture-diagram.html     ← older diagram (superseded by system-architecture-diagram.html)
│   │   ├── aws-account-setup-guide.html
│   │   └── bastion-rds-connection-guide.html ← SSM port forwarding + schema runner guide
│   └── terraform/
│       ├── bootstrap/
│       │   └── main.tf                 ← creates S3 state bucket + DynamoDB lock (run once)
│       └── environments/
│           └── production/             ← all prod AWS infra
│               ├── main.tf             ← provider + S3 backend
│               ├── variables.tf        ← includes data_bucket_name
│               ├── terraform.tfvars.example
│               ├── outputs.tf          ← includes api_endpoint
│               ├── vpc.tf              ← VPC, subnets, IGW, NAT
│               ├── security_groups.tf  ← sg-lambda, sg-rds, sg-elasticache, sg-bastion
│               ├── vpc_endpoints.tf    ← S3 gateway + Secrets Manager interface
│               ├── rds.tf              ← RDS PostgreSQL 16
│               ├── secrets.tf          ← Secrets Manager (DB credentials + JWT signing key iravi/dashboard/jwt)
│               ├── monitoring.tf       ← SNS + 5 CloudWatch alarms
│               ├── schema_runner.tf    ← removed (apply schema via SSM + psql)
│               ├── bastion.tf          ← Bastion EC2 — SSM Session Manager, no SSH
│               ├── lambda_etl_sales.tf ← ETL Lambda + shared S3 bucket notification (fans out to etl_sales on prefix "raw/RGF Sales Book", etl_stocks on "raw/Current", etl_customer_ledger on "raw/Ledger"; `eventbridge = true` added — S3 also forwards all events to EventBridge for etl_supplier_ledger)
│               ├── lambda_etl_stocks.tf ← Stock balance ETL Lambda (S3 trigger via shared notification in lambda_etl_sales.tf)
│               ├── lambda_etl_customer_ledger.tf ← Customer Ledger ETL Lambda (S3 trigger via shared notification; upserts customer_ledger with uni-temporal milestoning)
│               ├── lambda_etl_supplier_ledger.tf ← Supplier Ledger ETL Lambda (EventBridge trigger on raw/Ledger; read-only S3; upserts supplier_ledger; same file as etl_customer_ledger but different rows)
│               ├── lambda_redis_updater.tf ← Redis Updater + EventBridge trigger
│               ├── lambda_api.tf       ← API Lambda + API Gateway HTTP API; RBAC /auth/* + /admin/* routes (incl. POST /admin/cache/flush); CORS GET/POST/PUT/DELETE; GET /reports/customer-balances-fy route added (migration 010); GET /reports/supplier-balances-fy route added (migration 018); alerts CRUD routes added to api_rbac_routes (admin-only)
│               ├── ses.tf              ← SES domain identity + DKIM for alerts emails (alerts_domain var); outputs verification token + DKIM CNAMEs
│               ├── lambda_alerts_evaluator.tf ← Alerts Evaluator Lambda + EventBridge daily cron (05:30 UTC = 11:00 IST); reuses api_deps layer; env: DB_SECRET_ARN, ALERTS_SENDER_EMAIL; IAM: GetSecretValue + ses:SendEmail/SendRawEmail
│               └── amplify.tf          ← Amplify app env vars (VITE_API_BASE_URL only — dashboard creds removed; now BOOTSTRAP_ADMIN_* on the API Lambda); ONE-TIME import required before first apply
├── business-core\                      ← separate repo (processing logic)
│   ├── CLAUDE.md
│   └── lambda\
│       ├── etl_sales\                  ← Phase 1 active build target
│       ├── etl_customer_ledger\        ← Customer ledger ETL (handler + layer — scaffold needed)
│       ├── redis_updater\
│       └── api\
└── FileSyncAgent\                      ← separate repo (deployed on FUSIL PRO server)
```

---

## Architecture

```
FUSIL PRO (External)
    ↓ exports 8 Excel files to local server folder nightly
Local Export Folder (FUSIL PRO server)
    ↓ File Sync Agent (Python + Windows Task Scheduler)
S3 Landing Zone  s3://iravi-dashboard-tfstate-<acct>/
    raw/{date}/*.xlsx + manifest.json
    processed/{date}/  ← archived after ETL
    ↓ S3 event on manifest.json  |  EventBridge fallback 9PM IST
Data Extractor & Massager (AWS Lambda)
    ↓ upserts processed data
Dashboard DB (RDS PostgreSQL 16 — db.t3.small — ap-south-1)
    ↓ on ETL success
Redis Updater (AWS Lambda)
    ↓ 7-day TTL
ElastiCache Redis
    ↑ cache-aside (miss → Dashboard DB → populate Redis)
API Layer (API Gateway + Lambda + Cognito JWT)
    ↑
Dashboard UI (React + AWS Amplify)
    ↑
Users (Admin / Finance / Operations / Viewer)
```

**Two flows:**
- **Redis Enricher Flow (A→B→C→D):** nightly batch pipeline
- **Dashboard Flow (1→2→3):** on-demand UI requests

---

## Source Files (from FUSIL PRO)

FUSIL PRO exports **8 Excel files** to a local server folder each evening.
The File Sync Agent watches the folder and uploads to S3 once all 8 are present,
then generates `manifest.json` as the final step (pipeline trigger).

### File naming pattern
| File | Pattern |
|---|---|
| Sale | `RGF Sales Book{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Sale Returns | `RGF Sales Return Book{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Purchase | `RGF Purchase Book{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Purchase Returns | `RGF Purchase Return Report{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Expenses | `RGF Expenses*{DD-M-YYYY}({H.MM.SS}).xlsx` (file not yet seen — assumed similar) |
| Stocks | `Stocks.xlsx` (no date in filename) |
| Customer Accounts | `Customer Accounts Export File{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Customer Balances | `Customer Balances{DD-M-YYYY}({H.MM.SS}).xlsx` |

### Excel structure — all transaction files
```
Row 1: Company name (IRAVI AGRO LIFE LLP)
Row 2: Empty
Row 3: Report title
Row 4: Date range (From Date / To Date)
Row 5: Column headers   ← actual field names start here
Row 6+: Data rows
Last row(s): Totals / footer — first column is None, 'Total', or 'Date :'
```
**ETL must skip rows 1–5 and detect/skip total rows.**

### Column schemas (from actual file inspection)

**Sale** — invoice-level:
`Date, Voucher No, Branch, Party, Party GSTN, Qty, Gross, Disc, AV, CGST, SGST, IGST, Net, BillValue`

**Sale Returns** — invoice-level:
`Date, Voucher No, Branch, Location, Storage Bin, Party, Party GSTN, Ref BillNo, Ref BillDate, Qty, Gross, Disc, MRP Amount, GMD, AV, CGST, SGST, IGST, Net, Charges, ChrCGST, ChrSGST, ChrIGST, Deductions, Adjustments, Roundoff, BillValue, Remarks`

**Purchase** — invoice-level:
`Date, Voucher No, Branch, Party, Party GSTN, Ref BillDate, Qty, Gross, CGST, SGST, IGST, Net, Charges, ChrCGST, ChrSGST, ChrIGST, Roundoff, BillValue`

**Purchase Returns** — **line-item level** (one row per product per return voucher):
`Date, Voucher No, Branch, Party, Ref BillDate, Product, Qty, Rate, Gross, Disc Rate, Disc, MRP, GMD, AV, CGST Rate, CGST, SGST Rate, SGST, IGST Rate, IGST, Net, Barcodes, Narration`

**Stocks** — snapshot, two useful sheets:
- Sheet `Stocks`: `S No, PRODUCT, PACKING, AP(current), TS(current), AP(prev), TS(prev), Qty(current), Qty(prev), Rate, Opening, Closing`
  - Date of snapshot is in the **footer row** (`'Date :'` in first column)
  - Product name spans multiple packing rows — ETL must **forward-fill** `product_brand_name` and `s_no`
  - Blank separator rows between product groups — skip rows where all values are None
- Sheet `Margin 03-04`: `S No, PRODUCT, PACKING, COST PRICE, %, % of Margin, NRV PRICE, NRV`

**Customer Accounts** — master data, **no header rows** (Row 1 = column names directly):
`Name, ParentId, Code, Description, GST, GSTRegType, City, State, PIN, MobileNo, AltMobileNo, Email, PAN, LicenceNo, ...`

**Customer Balances** — snapshot, standard 5-row header:
`Branch, Party, Code, City, Debit, Credit, Balance, Balance In CC`
- Balance is a string like `"396324.00 Dr"` or `"86793.00 Cr"` — must be parsed to numeric + type
- `Dr` = customer owes (receivable), `Cr` = business owes customer
- Date comes from Row 4 `As At Date` field

---

## Database Schema (FINALIZED)

File: `IaC/db/schema.sql`
Target: Amazon RDS PostgreSQL 16 — database name `iravi_dashboard`

### Tables

| Table | Type | Upsert Key |
|---|---|---|
| `dim_customers` | Dimension | `customer_name` |
| `dim_packings` | Dimension | `packing_description` |
| `customer_details` | Dimension | `customer_name` |
| `fact_sales` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `fact_sales_returns` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `fact_purchases` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `fact_purchase_returns` | Fact (daily append) | `(voucher_no, transaction_date, product_name)` |
| `fact_expenses` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `snapshot_stock` | Snapshot (uni-temporal milestoned) | natural key `(brand, technical, packing_size, packing_configuration, branch, special_packing_mention, entry_date)` + `in_z`; `out_z IS NULL` = current |
| `snapshot_stock_margin` | Snapshot (replace per date) | `(snapshot_date, product_brand_name, packing_id)` |
| `snapshot_customer_balances` | Snapshot (replace per date) | `(snapshot_date, branch, customer_name)` |
| `customer_ledger` | Snapshot (uni-temporal milestoned) | natural key `(transaction_date, voucher_no, account_name, category, sub_category)`; `out_z IS NULL` = current |
| `appendix_b_x11_stock` | Snapshot (uni-temporal milestoned) | natural key `(barcode, technical_name, vendor)`; `out_z IS NULL` = current |
| `appendix_b_x11_stock_ledger` | Snapshot (uni-temporal milestoned) | natural key `(purchase_date, iravi_voucher, technical_name, barcode)`; `out_z IS NULL` = current |
| `purchases` | Snapshot (uni-temporal milestoned) | PK `(purchase_date, voucher_no, branch, party, product)`; `out_z IS NULL` = current; `purchase_return` = 'N' (AppendixPurchaseReport) or 'Y' (AppendixPurReturn) |
| `sales` | Snapshot (uni-temporal milestoned) | PK `(purchase_date, voucher_no, branch, party, product)`; `out_z IS NULL` = current; `sales_return` = 'N' (AppendixSale) or 'Y' (AppendixRetSales) |
| `etl_runs` | Audit | `run_date` |
| `app_roles` | RBAC | `role_name` |
| `app_screens` | RBAC (seeded) | `screen_key` |
| `app_role_screens` | RBAC map | `(role_id, screen_key)` |
| `app_users` | RBAC | `username` |
| `alerts` | Alerts config | `id` (SERIAL PK); `frequency` in (daily/weekly/monthly); `match_type` all/any; `schedule_time TIME DEFAULT '11:00:00'` (per-alert IST send time, added migration 014); `branch VARCHAR(100)` nullable (added migration 015 — scopes sales/sale_returns alerts to a branch; NULL or 'ALL' = all branches) |
| `alert_conditions` | Alerts filter rows | `alert_id` FK → alerts; `op` in (gt/gte/lt/lte/eq/between) |
| `alert_recipients` | Alert email addresses | `alert_id` FK → alerts; `channel` = 'email' |
| `alert_runs` | Alert audit log | `alert_id` FK → alerts; records each evaluator invocation |
| `supplier_accounts` | Master (uni-temporal milestoned) | natural key `name`; `out_z IS NULL` = current active supplier; business-core closes old row then inserts fresh one each run (migration 016) |
| `supplier_ledger` | Snapshot (uni-temporal milestoned) | natural key `(transaction_date, voucher_no, account_name, category, sub_category)`; `out_z IS NULL` = current; same shape as `customer_ledger`; populated by `etl_supplier_ledger` Lambda from the same "Ledger All Accounts" file (migration 017) |

### Migrations convention
One-off DML repairs and data fixes live in `db/migrations/` as numbered SQL files (`001_...`, `002_...`). They are not run automatically — apply manually via psql through the SSM tunnel. Always commit the migration file alongside the code change that made it necessary so the git history explains why it was run.

### Key schema decisions
- `source_date` was **removed** — lineage tracked via `ingested_at` + `etl_runs.files_processed`
- `dim_packings` normalises packing strings — now only used by `snapshot_stock_margin`; `snapshot_stock` dropped its `packing_id` FK (packing stored as `packing_size` + `packing_configuration` directly, matching process.py output)
- `snapshot_stock` uses **uni-temporal milestoning** (`in_z`/`out_z`): on re-run for the same `entry_date`, the old row is closed (`out_z = NOW()`) and a fresh row inserted (`in_z = NOW(), out_z = NULL`). A partial unique index on `WHERE out_z IS NULL` enforces exactly one active record per natural key. Superseded rows are retained for audit.
- `dim_customers` has no `address1/2/3` — only `city`, `state`, `pin` retained
- `fact_sales_returns` has no `party_group`, `party_address`, `party_mobile` — joinable from `dim_customers`
- `snapshot_customer_balances.balance_amount` is always positive numeric; direction in `balance_type` (`'Dr'`/`'Cr'`)
- `fact_expenses` schema is **provisional** — modelled after Purchase Book, will need adjustment when the Expenses file is seen (likely needs a `category` column)

---

## AWS Infrastructure (FINALIZED — Terraform written)

**Region:** `ap-south-1` (Mumbai)

### Security groups

| SG | Purpose |
|---|---|
| `sg_lambda_id` | Attached to all Lambda functions |
| `sg_rds_id` | RDS — inbound from Lambda SG + bastion SG |
| `sg_elasticache_id` | ElastiCache — inbound from Lambda SG + bastion SG |
| `sg_vpc_endpoints` | VPC Interface endpoint ENIs — inbound 443 from Lambda SG only |
| `sg_bastion` | Bastion EC2 — outbound 443 (SSM) + outbound 5432 to RDS + outbound 6379 to ElastiCache. No inbound rules. |

**Important:** Always use `sg_vpc_endpoints` (not `sg_lambda_id`) as the `security_group_ids` for any Interface VPC endpoint. Interface endpoint ENIs need an inbound rule; `sg_lambda_id` has none.

### Bastion host (RDS access via SSM Session Manager)
- Instance: `t3.micro`, Amazon Linux 2023, public subnet, `~$8/mo`
- No SSH port, no key pair, no IP allowlist — access via AWS SSM Session Manager
- IAM instance profile with `AmazonSSMManagedInstanceCore` attached to the instance
- Connect using SSM port forwarding — see README for step-by-step
- `terraform output bastion_instance_id` gives the instance ID needed for the SSM command

### GitHub Actions secrets (pipeline variables)

| Secret | Purpose |
|---|---|
| `AWS_ROLE_ARN` | OIDC: pipeline assumes `terraform-deployer` IAM role to authenticate with AWS |
| `TF_VAR_alert_email` | Terraform `alert_email` variable — SNS CloudWatch alarm email |
| `TF_VAR_dashboard_username` | Terraform `dashboard_username` variable — injected into Amplify as `VITE_DASHBOARD_USERNAME` |
| `TF_VAR_dashboard_password` | Terraform `dashboard_password` variable — injected into Amplify as `VITE_DASHBOARD_PASSWORD` |

### Terraform variables added for Alerts / SES

| Variable | Default | Description |
|---|---|---|
| `alerts_sender_email` | `noreply@iraviagrolife.com` | From address for SES-sent alert emails |
| `alerts_domain` | `iraviagrolife.com` | Domain registered with SES; DNS records output by `terraform output ses_dkim_tokens` must be added to your DNS provider |

### SES setup — two unavoidable manual steps

**Step 1 — DNS verification.** After the first `terraform apply` containing `ses.tf`, run:
```bash
terraform output ses_domain_verification_token   # add as TXT record: _amazonses.<domain>
terraform output ses_dkim_tokens                 # add 3 CNAMEs: <token>._domainkey.<domain> → <token>.dkim.amazonses.com
```
Add these records in your DNS provider. SES verifies automatically (usually within a few hours, up to 72 h).

**Step 2 — SES production access.** New AWS accounts start in the SES sandbox: outbound email is limited to verified addresses only. To send to arbitrary recipients (customers/admins), request production access:
- AWS Console → SES → Account dashboard → Request production access
- Fill in the support case (transactional use, daily volume estimate, CAN-SPAM compliance acknowledgement)
- Approval typically takes 1–2 business days
- Until approved, add each intended recipient address as a verified identity in SES to test in sandbox mode

`terraform.tfvars` is git-ignored. The pipeline reads these secrets as `TF_VAR_*` env vars instead — Terraform maps them automatically to the matching input variables.

### Pipeline dependency: business-core checkout required in ALL jobs
All three pipeline jobs (validate, plan, apply) must checkout `business-core` and create the symlink at `$GITHUB_WORKSPACE/../business-core`. Reason: Terraform's `filemd5()` and `archive_file` data sources reference Lambda source files in `business-core` and are evaluated at `terraform validate` time — not just at plan/apply. If business-core is missing, the validate job fails even though it doesn't need AWS credentials.

### S3 notification filter prefixes — avoid spaces
S3 notification filter prefixes containing spaces (e.g. `raw/Current Stock Balances`) silently fail to match even when the object key is correct. Use a prefix that stops before the first space (`raw/Current` instead of `raw/Current Stock Balances`). The Lambda handler must URL-decode the S3 event key with `unquote_plus()` because S3 delivers keys URL-encoded (`Current+Stock+Balances...` with `%28`/`%29` for parentheses) — the raw key from `record['s3']['object']['key']` cannot be used directly for filename comparisons or boto3 S3 calls.

### Lambda layer build pattern
Do NOT use `null_resource` + `local-exec` provisioner to run pip install inside Terraform. `data "archive_file"` does not reliably wait for provisioner output even with `depends_on`, causing "missing directory" errors on first apply. Instead: run pip install as an explicit GitHub Actions workflow step before `terraform init` in the plan and apply jobs. Each Lambda with a dependency layer gets its own named CI step. Current layers:
- `etl_stocks` → `.lambda_layers/etl_stocks/python/`
- `api_deps` → `.lambda_layers/api_deps/python/` — **shared** between `api` and `redis_updater` Lambdas
- `etl_customer_ledger` → `.lambda_layers/etl_customer_ledger/python/`
- `etl_supplier_accounts` → `.lambda_layers/etl_supplier_accounts/python/`
- `etl_supplier_ledger` → `.lambda_layers/etl_supplier_ledger/python/`

The step creates the directory with Linux-compatible wheels; Terraform's `archive_file` zips it normally. When adding a new Lambda with a layer, add the corresponding pip install step to both plan and apply jobs in `.github/workflows/terraform.yml`.

### Amplify — one-time import required
`amplify.tf` manages environment variables on an Amplify app that was **connected to GitHub manually** via the Amplify console. Before the first `terraform apply` on a fresh state, import the existing app into Terraform state:
```bash
terraform import aws_amplify_app.dashboard <AMPLIFY_APP_ID>
```
Find the App ID in the Amplify console URL (e.g. `d1a2b3c4e5f6g7`). Without this import, `terraform apply` will attempt to create a duplicate Amplify app.

### SES IAM — domain identity vs address-level identity
SES has two flavours of verified identity: **domain** (`identity/iraviagrolife.com`) and **address** (`identity/kranthi@iraviagrolife.com`). When a Lambda calls `ses:SendEmail`, AWS evaluates the IAM policy against the ARN of the **sender** identity, not the domain. If the From address is `kranthi@iraviagrolife.com` and the policy `Resource` only covers `identity/iraviagrolife.com`, the call gets `AccessDenied` even though the domain is verified.

Fix: scope the SES `Resource` to a two-element list — the domain identity ARN **plus** `arn:aws:ses:<region>:<account>:identity/*` — so any verified identity under the account/region is authorised. `data.aws_caller_identity.current` (already declared in `main.tf`) and `var.aws_region` provide the interpolation values.

### Terraform outputs needed downstream
After `terraform apply`, capture these — they are inputs to every Lambda built next:
```
sg_lambda_id        ← attach to ALL Lambda functions
private_subnet_ids  ← attach ALL Lambda functions and ElastiCache
db_secret_arn       ← Lambda IAM policies (GetSecretValue)
sns_alerts_arn      ← ETL failure notifications
sg_elasticache_id   ← ElastiCache cluster (not yet provisioned)
```

### DB credentials
Stored in Secrets Manager at path `iravi/dashboard/db`:
```json
{ "host": "...", "port": 5432, "dbname": "iravi_dashboard", "username": "dashboard_admin", "password": "..." }
```
Lambda connection pattern: open connection outside the handler, cache for execution environment lifetime.

---

## ETL Logic Decisions

### Trigger chain
1. FUSIL PRO drops files to local folder
2. File Sync Agent (runs every 15 min from 7PM IST) detects all 8 files, uploads to `s3://.../raw/{date}/`, generates `manifest.json` last
3. S3 `ObjectCreated` event on `manifest.json` triggers ETL Lambda
4. EventBridge cron at 9PM IST is a safety fallback
5. CloudWatch alarm fires if no successful ETL run detected by 9:30PM IST

### ETL idempotency
All fact table writes use `INSERT ... ON CONFLICT DO NOTHING` (or `ON CONFLICT DO UPDATE`) on the unique constraint. Re-running the same file produces no duplicates.

### Data strategies
| Data type | Strategy |
|---|---|
| Sales, Purchases, Expenses, Returns | Daily incremental append |
| Stock snapshot | Full replace per `snapshot_date` |
| Customer balances | Full replace per `snapshot_date` |
| Customer accounts | Upsert on `customer_name` |

### Historical migration
- Transaction files: **1 month** back from go-live (one-time manual ETL run)
- Stock report: **no history** — starts from go-live day (snapshot only, no historical data available)
- Customer accounts: current export only

### ETL audit
Every run writes a row to `etl_runs`: `run_date`, `started_at`, `completed_at`, `status` (`running`/`success`/`failed`), `files_processed` (JSONB list of filenames), `error_message`.

---

## Alerting Matrix

| Alert | Condition | Raised by |
|---|---|---|
| Files not exported | No files in local folder by 7:45PM IST | File Sync Agent |
| S3 upload failed | Upload error after 3 retries | File Sync Agent |
| ETL not triggered | No manifest in `raw/{today}/` by 9:30PM IST | CloudWatch |
| ETL failed | Lambda exits with error | CloudWatch → SNS |
| Redis update failed | Redis Updater Lambda error | CloudWatch → SNS |

---

## RBAC Roles (AWS Cognito)

| Role | Access |
|---|---|
| Admin | All views + user management + ETL run history |
| Finance | All views including Finance Overview (P&L) |
| Operations | Sales, Purchases, Inventory, Expenses, Customer list (no balances) |
| Viewer | Executive Summary only — read-only |

---

## Dashboard Views (to be built)

1. **Executive Summary** — KPI cards: sales, gross margin, net cash, outstanding receivables, stock value
2. **Sales Analytics** — trends, net sales (gross − returns), by branch, top customers
3. **Expense Tracker** — by category, trend, vs revenue ratio
4. **Purchases & Inventory** — net purchases, stock levels by product/packing, AP vs TS split, margin view
5. **Customer Management** — balances, AR aging (0-30 / 31-60 / 61-90 / 90+ days)
6. **Finance Overview** — P&L summary, MoM comparison, cash flow (Finance role only)

---

## What Is Built

- [x] System design finalized and documented
- [x] Stakeholder presentation HTML (`design/stakeholder-presentation.html`)
- [x] Database schema DDL (`IaC/db/schema.sql`)
- [x] Database schema diagram (`IaC/db/schema.mmd`)
- [x] Terraform — VPC, subnets, security groups, VPC endpoints (`IaC/terraform/`)
- [x] Terraform — RDS PostgreSQL 16 instance
- [x] Terraform — Secrets Manager (DB credentials)
- [x] Terraform — SNS + CloudWatch alarms
- [x] Terraform — Schema Runner Lambda (removed — schema applied via SSM + psql)
- [x] IaC README with full deployment runbook
- [x] Security review — VPC endpoint SG bug fixed, IAM scoped, SG descriptions added
- [x] GitHub Actions pipeline — all 3 stages active (fmt + validate on PR, plan on PR, apply on merge to main)
- [x] Terraform — Bastion host EC2 with SSM Session Manager (no SSH, no key pair, no IP allowlist)
- [x] AWS architecture diagram (`design/aws-architecture-diagram.html`)
- [x] System architecture diagrams refreshed (2026-06-25) — `design/system-architecture-diagram.html` (SVG, dark theme) and `design/combined-system-architecture.html` (HTML ref-arch style) updated to include: Alerts subsystem (EventBridge cron rate(15 min) → alerts_evaluator Lambda → Amazon SES → email recipients); alerts/alert_conditions/alert_recipients/alert_runs tables (mig 013–014); GET /reports/customer-balances-fy and GET|POST|PUT|DELETE /alerts/* routes on API Lambda; SES node (ses.tf); customer_details.customer_code (mig 011); customer_ledger.amount precision (mig 012). Both files are git-ignored (local only — open in browser for visual check).
- [x] AWS account setup guide (`design/aws-account-setup-guide.html`)
- [x] AWS Account + OIDC setup — account live, `terraform-deployer` role created, pipeline stages 2 & 3 enabled, `terraform apply` run, all infra provisioned
- [x] File Sync Agent — deployed and running on FUSIL PRO server · `D:\Projects\Iravi\FileSyncAgent\`
- [x] business-core project created — `D:\Projects\Iravi\business-core\` with lambda scaffolds for etl_sales, redis_updater, api
- [x] Terraform — Lambda resources (`lambda_etl_sales.tf`, `lambda_redis_updater.tf`, `lambda_api.tf`) with IAM, triggers, API Gateway
- [x] Terraform — `lambda_etl_stocks.tf` — stock balance ETL Lambda; `lambda_etl_sales.tf` bucket notification fans out to both Lambdas using non-overlapping suffixes (`).xlsx` for dated exports → etl_sales; `Stocks.xlsx` → etl_stocks). Phase 2 note: when additional ETL Lambdas are added for purchases/returns/expenses they will share the `).xlsx` suffix — switch to EventBridge or a dispatcher Lambda at that point.
- [x] Terraform — `elasticache.tf` — ElastiCache Redis 7, `cache.t3.micro`, private subnets, `sg_elasticache` (already existed)
- [x] Terraform — `lambda_etl_stocks.tf` updated — added `EVENT_BUS_NAME` env var + `events:PutEvents` IAM permission
- [x] Terraform — `lambda_redis_updater.tf` updated — added `REDIS_HOST` env var; added `ETLStocksSuccess` EventBridge rule + target + permission
- [x] Terraform — `lambda_api.tf` updated — added `REDIS_HOST` env var; added `GET /stocks/summary` and `GET /stocks/current` routes
- [x] Terraform — `outputs.tf` updated — added `elasticache_host` output
- [x] business-core — `etl_stocks/handler.py` — emits `ETLStocksSuccess` EventBridge event after successful DB upsert
- [x] business-core — `redis_updater/handler.py` — fully implemented: handles `ETLStocksSuccess` (stocks cache) and `ETLSalesSuccess` (stub); writes `iravi:stocks:summary` + `iravi:stocks:current` to Redis with 24h TTL
- [x] business-core — `api/handler.py` — fully implemented: `GET /stocks/summary` and `GET /stocks/current` with cache-aside (Redis → RDS fallback); `GET /sales` stub
- [x] Dashboard UI — `D:\Projects\Iravi\ui\` — Vite + React + TypeScript + Tailwind; sidebar nav (Sales, Purchases, Stocks, Customers, Reports); Current Stocks page with 4 stat tiles + filterable/sortable table; deployed via AWS Amplify Hosting
- [x] DB migrations folder — `db/migrations/` established; `001_repair_snapshot_stock_duplicates.sql` closes pre-index duplicate `out_z IS NULL` rows (applied 2026-06-03)
- [x] DB migrations — `002_repair_customer_ledger_duplicates.sql` — defensive duplicate-close script for `customer_ledger` (not yet applied; run if ETL ever inserts without milestoning)
- [x] DB migrations — `003_add_voucher_no_to_customer_ledger.sql` — adds `voucher_no VARCHAR(50) NOT NULL` column and rebuilds `uix_customer_ledger_active` to include it; safe to run (table exists, no data inserted yet)
- [x] DB migrations — `004_create_customer_details.sql` — creates `customer_details` table (upsert on `customer_name`); also added to `schema.sql`
- [x] DB migrations — `005_create_appendix_b_x11_stock.sql` — creates `appendix_b_x11_stock` (Barcodes Masters export); uni-temporal milestoned, natural key `(barcode, technical_name, vendor)`
- [x] DB migrations — `006_create_appendix_b_x11_stock_ledger.sql` — creates `appendix_b_x11_stock_ledger` (AppendixPurchaseReport export); uni-temporal milestoned, natural key `(purchase_date, iravi_voucher, technical_name, barcode)`
- [x] DB migrations — `007_create_purchases.sql` — creates `purchases` (line-item purchase ledger, AppendixPurchaseReport + AppendixPurReturn); uni-temporal milestoned, PK `(purchase_date, voucher_no, branch, party, product)`
- [x] DB migrations — `008_create_sales.sql` — creates `sales` (line-item sales ledger, AppendixSale + AppendixRetSales); same shape as `purchases` with `sales_return` in place of `purchase_return`; uni-temporal milestoned, PK `(purchase_date, voucher_no, branch, party, product)`
- [x] Terraform — `lambda_etl_customer_ledger.tf` — Customer Ledger ETL Lambda; S3 trigger on prefix `raw/Ledger` (matches `Ledger All Accounts*.xlsx`); upserts `customer_ledger` with uni-temporal milestoning; emits EventBridge event; has own pip layer (built by CI step "Build etl_customer_ledger layer"); `lambda_etl_sales.tf` bucket notification updated to fan out to all 3 ETL Lambdas
- [x] Terraform — `amplify.tf` — manages Amplify app environment variables (`VITE_API_BASE_URL`, `VITE_DASHBOARD_USERNAME`, `VITE_DASHBOARD_PASSWORD`); app was connected to GitHub manually — one-time `terraform import` required before first apply; `amplify_default_domain` added to outputs
- [x] Terraform — `lambda_api.tf` updated — `api_deps` shared layer (psycopg2 + redis-py, linux wheels) used by both api and redis_updater; CORS configured for `dashboard.iraviagrolife.com`
- [x] CI workflow — "Build etl_customer_ledger layer" and "Build api-deps layer" steps added to both plan and apply jobs
- [x] RBAC phase 1 — DB migration `009_create_rbac.sql` (app_roles/app_screens/app_role_screens/app_users); JWT signing key secret `iravi/dashboard/jwt` (`secrets.tf`); API Lambda env `JWT_SECRET_ARN` + `BOOTSTRAP_ADMIN_*`, IAM for the jwt secret, `/auth/*` + `/admin/*` routes, CORS PUT/DELETE (`lambda_api.tf`); dashboard creds removed from Amplify bundle (`amplify.tf`). Login + `/admin/*` enforced server-side; data endpoints are UI-only gated (full enforcement = backlog)
- [x] Admin cache flush — `POST /admin/cache/flush` route added to `api_rbac_routes` (`lambda_api.tf`); API Lambda handler deletes all `iravi:*` Redis keys (namespace-scoped, not FLUSHDB) so the cache rehydrates from RDS on next request; UI exposes it as an admin-only button left of the dark-mode toggle in the navbar (`iravi-ui` Layout). Requires IaC apply for the route + Lambda redeploy to take effect
- [x] Terraform — `lambda_api.tf` updated — `GET /reports/customer-balances-fy` route added (`aws_apigatewayv2_route.reports_customer_balances_fy`); same per-path explicit route pattern as all other data routes; CORS already covers GET via the existing `cors_configuration` block — no CORS change needed
- [x] DB migrations — `010_add_customer_balances_fy_screen.sql` — idempotently inserts `app_screens` seed row `('reports.customer_balances_fy', 'Customer Balances (FY)', 90)` with `ON CONFLICT (screen_key) DO NOTHING`; RBAC key for the new Customer Balances (FY) report screen; NOT YET APPLIED — apply manually via psql over the SSM tunnel post-merge
- [x] DB migrations — `011_add_customer_code_to_customer_details.sql` — adds `customer_code VARCHAR(20)` (nullable) to `customer_details` plus `idx_customer_details_code` index; sourced from the "General" sheet of the Customer Accounts Export File by `etl_customer_accounts`; NOT YET APPLIED — MUST be applied manually via psql over the SSM tunnel BEFORE the updated `etl_customer_accounts` Lambda runs
- [x] DB migrations — `012_widen_customer_ledger_amount.sql` — widens `customer_ledger.amount` from `NUMERIC(15,2)` to `NUMERIC(15,4)`; the "Ledger All Accounts" export contains GST component lines at 3 decimal places (e.g. 6498.675) — storing at 2dp rounded them and produced a 1-paise drift when components were summed per voucher; schema.sql updated to match; NOT YET APPLIED — apply manually via psql over the SSM tunnel, then RE-INGEST the ledger file(s) (existing rows were already truncated and cannot be recovered by the ALTER alone), then flush the Redis cache
- [x] DB migrations — `013_create_alerts.sql` — creates `alerts`, `alert_conditions`, `alert_recipients`, `alert_runs` tables with check constraints; all relational (no JSONB); schema.sql updated to match; NOT YET APPLIED — apply manually via psql over the SSM tunnel post-merge
- [x] Terraform — `ses.tf` — SES domain identity for `var.alerts_domain` (default `iraviagrolife.com`) + DKIM configuration; outputs `ses_domain_verification_token`, `ses_dkim_tokens` (3 CNAMEs), `ses_identity_arn`; `aws_ses_configuration_set` named `${project}-alerts`; two manual steps required: (a) add DNS records, (b) request SES production access
- [x] Terraform — `lambda_alerts_evaluator.tf` — Alerts Evaluator Lambda (`python3.12`, handler `handler.lambda_handler`, 256 MB, 300 s timeout); reuses `api_deps` layer (psycopg2); VPC private subnets + sg_lambda; env: `DB_SECRET_ARN`, `ALERTS_SENDER_EMAIL`; IAM: GetSecretValue on DB secret + ses:SendEmail/SendRawEmail; EventBridge schedule changed from daily `cron(30 5 * * ? *)` (11:00 IST) to `rate(15 minutes)` — send time is now per-alert (`alerts.schedule_time`); business-core Lambda self-selects which alerts are due each invocation. **SES IAM scoping fix (2026-06-25):** `Resource` in the SES statement was broadened from the domain identity ARN alone to a two-element list — `[aws_ses_domain_identity.alerts.arn, "arn:aws:ses:<region>:<account>:identity/*"]` — because SES authorises `SendEmail` against the *sender* identity ARN, and an address-level verified identity (e.g. `kranthi@iraviagrolife.com`) resolves to `identity/kranthi@iraviagrolife.com`, not `identity/iraviagrolife.com`; the domain-only scope caused `AccessDenied`.
- [x] DB migrations — `014_add_alert_schedule_time.sql` — adds `schedule_time TIME NOT NULL DEFAULT '11:00:00'` to `alerts` table; default preserves legacy 11:00 IST behaviour for existing rows; schema.sql updated to match; NOT YET APPLIED — apply manually via psql over the SSM tunnel post-merge
- [x] Terraform — `lambda_api.tf` alerts routes — `GET /alerts`, `POST /alerts`, `PUT /alerts/{id}`, `DELETE /alerts/{id}`, `GET /alerts/fields`, `POST /alerts/{id}/test` added to `api_rbac_routes` local; enforced in Lambda handler (valid JWT + is_admin); CORS already covers all methods via existing cors_configuration block
- [x] DB migrations — `015_add_alert_branch.sql` — adds nullable `branch VARCHAR(100)` column to `alerts` table; scopes sales/sale_returns category alerts to a specific branch (NULL or 'ALL' = all branches; balances alerts ignore this column); schema.sql updated to match; NOT YET APPLIED — apply manually via psql over the SSM tunnel post-merge; alerts_evaluator branch-filter logic lives in business-core (no IaC Lambda change required — redeploys on next apply)
- [x] DB migrations — `016_create_supplier_accounts.sql` — creates `supplier_accounts` table (uni-temporal milestoned, natural key `name`, BIGSERIAL PK); partial unique index `uix_supplier_accounts_active` enforces one active row per supplier name; schema.sql updated to match; NOT YET APPLIED — apply manually via psql over the SSM tunnel post-merge after terraform apply has provisioned `lambda_etl_supplier_accounts`
- [x] Terraform — `lambda_etl_supplier_accounts.tf` — Supplier Accounts ETL Lambda (`python3.12`, handler `handler.lambda_handler`, 256 MB, 120 s); own pip layer at `.lambda_layers/etl_supplier_accounts/`; IAM: VPCNetworking + Logs + SecretsManager(db) + S3 Get/Put/Delete + ListBucket; env: DATA_BUCKET, DB_SECRET_ARN; VPC private subnets + sg_lambda; source: `business-core/lambda/etl_supplier_accounts/`; business-core must be pushed BEFORE this repo is planned/applied
- [x] Terraform — `lambda_etl_sales.tf` shared S3 bucket notification extended — added `lambda_function` block for `etl_supplier_accounts` with prefix `raw/Supplier` and suffix `.xlsx`; `aws_lambda_permission.s3_invoke_etl_supplier_accounts` added to `depends_on`; no new `aws_s3_bucket_notification` resource created (single-resource-per-bucket rule preserved)
- [x] CI — `.github/workflows/terraform.yml` — "Build etl_supplier_accounts layer" pip-install step added to BOTH the plan job AND the apply job; installs into `.lambda_layers/etl_supplier_accounts/python/` with linux-compatible wheels
- [x] DB migrations — `017_create_supplier_ledger.sql` — creates `supplier_ledger` table (identical shape to `customer_ledger`, uni-temporal milestoned, natural key `(transaction_date, voucher_no, account_name, category, sub_category)`); same indexes pattern; NOT YET APPLIED — apply MANUALLY via psql over the SSM tunnel post-merge
- [x] Terraform — `lambda_etl_supplier_ledger.tf` — Supplier Ledger ETL Lambda (`python3.12`, 512 MB, 300 s); own pip layer at `.lambda_layers/etl_supplier_ledger/`; IAM: VPCNetworking + Logs + SecretsManager(db) + S3 **read-only** (`s3:GetObject` on bucket/* and `s3:ListBucket` on bucket arn — no PutObject, no DeleteObject, no events:PutEvents); env: DATA_BUCKET, DB_SECRET_ARN, RAW_PREFIX, PROCESSED_PREFIX; VPC private subnets + sg_lambda; triggered via EventBridge "Object Created" rule (NOT an S3 notification — avoids the overlapping-prefix conflict with etl_customer_ledger); source: `business-core/lambda/etl_supplier_ledger/`
- [x] Terraform — `lambda_etl_sales.tf` `aws_s3_bucket_notification.etl_trigger` — added `eventbridge = true` (single additive line); enables S3 to forward all object events to EventBridge so the new `s3_ledger_object_created` rule in `lambda_etl_supplier_ledger.tf` fires; no existing `lambda_function {}` blocks were touched
- [x] CI — `.github/workflows/terraform.yml` — "Build etl_supplier_ledger layer" pip-install step added to BOTH the plan job AND the apply job; installs into `.lambda_layers/etl_supplier_ledger/python/` with linux-compatible wheels
- [x] Terraform — `lambda_api.tf` updated — `GET /reports/supplier-balances-fy` route added (`aws_apigatewayv2_route.reports_supplier_balances_fy`); same explicit per-path route pattern as `reports_customer_balances_fy`; CORS already covers GET via the existing `cors_configuration` block — no CORS change needed; data report routes are NOT listed in `api_rbac_routes` (only /auth, /admin, /alerts live there) so no change to that local
- [x] DB migrations — `018_add_supplier_balances_fy_screen.sql` — idempotently inserts `app_screens` seed row `('reports.supplier_balances_fy', 'Supplier Balances (FY)', 91)` with `ON CONFLICT (screen_key) DO NOTHING`; RBAC key for the new Supplier Balances (FY) report screen; mirrors `010_add_customer_balances_fy_screen.sql`; `db/schema.sql` seeded `app_screens` block updated to include sort_order 91 row for consistency; NOT YET APPLIED — apply manually via psql over the SSM tunnel post-merge; admins must then map `reports.supplier_balances_fy` to roles via the Access Control screen in the dashboard

**Stocks pipeline is complete end-to-end.** Current Stocks UI is built and ready to deploy. Redis cache is populated nightly by redis_updater after `ETLStocksSuccess` event.

**Redis key schema (stocks):**
- `iravi:stocks:summary` — `{total_kgs, total_vols, stock_valuation, total_products, as_of, updated_at}`, 24h TTL
- `iravi:stocks:current` — JSON array of all active `snapshot_stock` rows, 24h TTL
- Unit classification for tiles: packing_size scanned for `KG|GMS|GM` (weight) vs `LTR|LT|ML|L` (volume) using Python regex

**UI stack decision:** Vite + React + TypeScript + Tailwind CSS. No shadcn/ui dependency — components written in plain Tailwind. Client-side filtering/sorting on the ~500-row dataset (no extra API calls needed).

## What Is Next (build in this order)

- [ ] **Deploy Terraform** — apply `elasticache.tf` + updated Lambda configs via GitHub Actions; capture `elasticache_host` output
- [ ] **Deploy UI** — connect `D:\Projects\Iravi\ui\` to AWS Amplify Hosting; set `VITE_API_BASE_URL` in Amplify console to value of `terraform output api_endpoint`
- [ ] **Test stocks flow end-to-end** — upload real `Current Stock Balances*.xlsx` to `raw/` in S3, verify `snapshot_stock` rows in RDS, verify Redis keys populate, verify UI tiles + table render correctly

- [ ] **Implement etl_sales handler** — parse `RGF Sales Book*.xlsx` (skip rows 1–5, detect total rows); upsert `dim_customers` + `fact_sales`; emit `ETLSalesSuccess`; move file to `processed/`
- [ ] **Implement etl_customer_ledger handler** — scaffold `business-core/lambda/etl_customer_ledger/handler.py`; parse `Ledger All Accounts*.xlsx`; skip "Brought Forward" rows; two-step milestoning upsert into `customer_ledger`; emit `ETLCustomerLedgerSuccess`; move file to `processed/` (CI layer build step already exists)
- [ ] **Implement `_update_sales_cache()`** in redis_updater once etl_sales is verified

- [ ] **Cognito** — add Terraform; JWT authoriser on API Gateway; Amplify Authenticator in UI

- [ ] **One-time historical migration** — 1 month of transaction files through ETL Lambda; stock history starts from go-live

### Alerts feature — remaining manual steps (system is DEPLOYED; these are post-deploy operational tasks)
- [x] `business-core/lambda/alerts_evaluator/` pushed before IaC merge (Terraform validates source at plan time); evaluator self-selects alerts by `schedule_time` on each 15-minute invocation; now also handles `sales` and `sale_returns` aggregate alert categories in addition to `balances` — branch-scoped evaluation controlled by `alerts.branch` (migration 015)
- [x] `terraform apply` has provisioned `ses.tf` + `lambda_alerts_evaluator.tf` (EventBridge rate(15 min) cron, IAM, env vars)
- [x] Migration `013_create_alerts.sql` applied manually via psql over the SSM tunnel
- [x] Migration `014_add_alert_schedule_time.sql` applied manually via psql over the SSM tunnel (`schedule_time` column on `alerts` table)
- [ ] SES DNS records — run `terraform output ses_dkim_tokens` and add the 3 CNAMEs + TXT `_amazonses` record to the DNS provider; SES auto-verifies within 72 h
- [ ] Request SES production access via AWS Console (Account dashboard → Request production access); until approved, add each alert recipient as a verified identity in SES sandbox
- [ ] iravi-ui: build the Alerts admin screen (`GET/POST/PUT/DELETE /alerts`, `GET /alerts/fields`, `POST /alerts/{id}/test`); expose `schedule_time` as a time-picker field on the alert form

---

## Key Technical Choices

| Decision | Choice | Reason |
|---|---|---|
| Language (Lambdas) | Python 3.12 | Faster to write ETL/data code, openpyxl for Excel parsing |
| DB driver | psycopg2 | Standard PostgreSQL driver for Python |
| Excel parsing | openpyxl | Handles .xlsx, reads cell values cleanly |
| Redis client | redis-py | Standard Python Redis client |
| IaC | Terraform | Reproducible, version-controlled |
| Auth | AWS Cognito | Native AWS, integrates with API Gateway |
| Frontend | React + Amplify | Good charting ecosystem, Amplify handles CI/CD + hosting |
| AWS region | ap-south-1 | Closest to business location |
| RDS Multi-AZ | No (for now) | Dashboard is not mission-critical — add later |
| RDS Proxy | No (for now) | Low concurrency — add if connection exhaustion becomes an issue |

---

## Current Cost Estimate (ap-south-1)

| Resource | Monthly |
|---|---|
| RDS db.t3.small | ~$29 |
| NAT Gateway | ~$44 |
| Secrets Manager endpoint | ~$10 |
| Bastion EC2 t3.micro (24/7) | ~$10 |
| CloudWatch + S3 | ~$3 |
| **Total** | **~$95/mo** (~$89 if bastion stopped when idle) |

## Prospective Cost Saving Avenues

Items confirmed as not worth doing now but worth revisiting as traffic and costs grow.
Do not act on these without explicit discussion — they are parked here for reference.

| # | Change | Estimated Saving | When to do it | Notes |
|---|---|---|---|---|
| 1 | **VPC endpoints for CloudWatch Logs + SNS** | ~$5–10/mo | When ETL log volume grows or NAT costs spike | Lambda logs and SNS publishes currently route through NAT Gateway. Two interface endpoints (~$16/mo combined) would eliminate that traffic. Pays for itself once log volume is meaningful. |
| 2 | **RDS Reserved Instance (1-year, no upfront)** | ~$8–9/mo | After 3–6 months of stable usage — confirm instance size is right first | 30% discount on the DB compute cost. No code or infrastructure change — purchase via AWS console. Pointless to reserve before knowing if `t3.small` is the right size. |
| 3 | **Lambda Graviton (arm64 runtime)** | ~10–20% on Lambda compute | After all Lambda functions are created and stable | One-line Terraform change per function: `architectures = ["arm64"]`. Python 3.12 supports arm64 natively. Do this as a batch change across all Lambdas once ETL, Redis Updater, and API functions exist. |

---

## Data Freshness Contract

Dashboard shows data **as of the previous evening's export (~8PM IST)**.
A user viewing at 7AM sees data current to the prior day.
This expectation has been set with stakeholders.

Stock trend data is only available from go-live date — no historical stock snapshots exist.
