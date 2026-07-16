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
│   │       ├── 011_add_customer_code_to_customer_details.sql
│   │       ├── 012_widen_customer_ledger_amount.sql
│   │       ├── 013_create_alerts.sql
│   │       ├── 014_add_alert_schedule_time.sql
│   │       ├── 015_add_alert_branch.sql
│   │       ├── 016_create_supplier_accounts.sql
│   │       ├── 017_create_supplier_ledger.sql
│   │       ├── 018_add_supplier_balances_fy_screen.sql
│   │       ├── 019_add_monthly_sales_screen.sql
│   │       ├── 020_add_supplier_balances_screen.sql
│   │       ├── 021_add_supplier_ledger_statement_screen.sql
│   │       ├── 026_create_procurement_schema.sql       ← procurement schema + 5 CRUD tables
│   │       ├── 027_add_procurement_screens.sql         ← RBAC seeds procurement.* screens
│   │       ├── 028_seed_procurement_data.sql           ← seed from IAL Enquiry.xlsx
│   │       ├── 029_add_procurement_overview_screen.sql ← seeds procurement.overview screen
│   │       ├── 030_add_procurement_enquiry_search_screen.sql ← seeds procurement.enquiry_search screen
│   │       ├── 032_add_supplier_company_address.sql          ← procurement.supplier_companies +address/state/pin/gstin
│   │       ├── 033_create_procurement_packaging_meta.sql     ← procurement.packaging_meta (master KG/LTR size lists)
│   │       ├── 034_seed_procurement_packaging_meta.sql       ← seeds KG+LTR sizes from Opening Stock PDF
│   │       ├── 035_create_procurement_packagings.sql         ← procurement.packagings (brand → meta size)
│   │       ├── 036_add_procurement_packaging_screens.sql     ← seeds packaging_meta + packagings screens
│   │       ├── 037_create_procurement_signatory_authorities.sql       ← procurement.signatory_authorities
│   │       ├── 038_add_procurement_signatory_authority_screen.sql     ← seeds procurement.signatory_authorities screen
│   │       ├── 039_create_procurement_purchase_orders.sql             ← procurement.purchase_orders (Bulk PO)
│   │       └── 040_add_procurement_purchase_order_screen.sql          ← seeds procurement.purchase_orders screen
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
│               ├── elasticache.tf      ← ElastiCache Redis 7 (cache.t3.micro, private subnets)
│               ├── s3_data.tf          ← S3 data bucket (raw/ processed/ notifications/)
│               ├── secrets.tf          ← Secrets Manager (DB credentials + JWT signing key iravi/dashboard/jwt)
│               ├── monitoring.tf       ← SNS + 5 CloudWatch alarms
│               ├── schema_runner.tf    ← removed (apply schema via SSM + psql)
│               ├── bastion.tf          ← Bastion EC2 — SSM Session Manager, no SSH
│               ├── lambda_etl_sales.tf ← ETL Lambda + shared S3 bucket notification (fans out to ALL S3-triggered ETL Lambdas by non-overlapping raw/ prefix; `eventbridge = true` — S3 also forwards events to EventBridge for etl_supplier_ledger)
│               ├── lambda_etl_stocks.tf ← Stock balance ETL Lambda (raw/Current)
│               ├── lambda_etl_customer_ledger.tf   ← Customer Ledger ETL Lambda (raw/Ledger)
│               ├── lambda_etl_customer_accounts.tf ← Customer Accounts ETL Lambda (raw/Customer)
│               ├── lambda_etl_appendix_b_x11.tf                 ← Barcodes Masters (raw/Barcodes)
│               ├── lambda_etl_appendix_b_x11_purchase.tf        ← AppendixPurchase
│               ├── lambda_etl_appendix_b_x11_purchase_return.tf ← AppendixPurReturn
│               ├── lambda_etl_appendix_b_x11_sale.tf            ← AppendixSale
│               ├── lambda_etl_appendix_b_x11_sale_return.tf     ← AppendixRetSales
│               ├── lambda_etl_supplier_accounts.tf ← Supplier Accounts ETL Lambda (raw/Supplier)
│               ├── lambda_etl_supplier_ledger.tf ← Supplier Ledger ETL Lambda (EventBridge trigger on raw/Ledger; read-only S3; upserts supplier_ledger; same source file as etl_customer_ledger but different rows)
│               ├── lambda_whatsapp_notifier.tf ← WhatsApp notifier Lambda (notifications/pending/*.html)
│               ├── lambda_redis_updater.tf ← Redis Updater + EventBridge trigger
│               ├── lambda_api.tf       ← API Lambda + API Gateway HTTP API; RBAC /auth/* + /admin/* routes (incl. POST /admin/cache/flush); CORS GET/POST/PUT/DELETE; GET /reports/customer-balances-fy route added (migration 010); GET /reports/supplier-balances-fy route added (migration 018); GET /reports/monthly-sales route added (migration 019); alerts CRUD routes added to api_rbac_routes (admin-only)
│               ├── ses.tf              ← SES domain identity + DKIM for alerts emails (alerts_domain var); outputs verification token + DKIM CNAMEs
│               ├── lambda_alerts_evaluator.tf ← Alerts Evaluator Lambda + EventBridge rate(15 min); layers: api_deps (psycopg2) + alerts_evaluator_deps (reportlab — PDF for Monthly Sales email); env: DB_SECRET_ARN, ALERTS_SENDER_EMAIL; IAM: GetSecretValue + ses:SendEmail/SendRawEmail
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
    ↓ File Sync Agent exports 7 Excel reports (+ Appendix-B/Ledger/Supplier/Barcodes files) nightly
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
    ↓ per-key TTL (stocks/ledger-range 24h; API cache-aside keys 15m–1h)
ElastiCache Redis
    ↑ cache-aside (miss → Dashboard DB → populate Redis)
API Layer (API Gateway + Lambda + app-level JWT/RBAC; Cognito is future phase 3)
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

The File Sync Agent drives FUSIL PRO to export **7 Excel reports** (see `FileSyncAgent/src/fusil/reports.py`,
the authoritative list), uploads them to S3, then writes `manifest.json` as the final step (pipeline trigger).
There is **no Expenses report** — the original spec was wrong. Additional source files consumed by the ETL
Lambdas (Appendix-B purchase/sale, `Ledger All Accounts`, `Supplier Accounts`, `Barcodes Masters`, product
rates) are exported separately and land under their own `raw/` prefixes.

### File naming pattern (7 agent-exported reports)
| File | Pattern |
|---|---|
| Sale | `RGF Sales Book{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Sale Returns | `RGF Sales Return Book{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Purchase | `RGF Purchase Book{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Purchase Returns | `RGF Purchase Return Book{DD-M-YYYY}({H.MM.SS}).xlsx` |
| Stocks | `RGF Current Stock Balances{DD-M-YYYY}({H.MM.SS}).xlsx` |
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
- `alerts_evaluator_deps` → `.lambda_layers/alerts_evaluator_deps/python/` — `reportlab` (PDF generation for Monthly Sales email attachments); **alerts_evaluator-specific**, not merged into `api_deps`

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

## RBAC (DB-backed, phase 1 — implemented)

RBAC is **not** Cognito-based (Cognito on API Gateway remains future phase 3). Roles and their screen
access live in Postgres and are managed via the `/admin/*` API:

- Tables (migration `009_create_rbac.sql`): `app_users`, `app_roles`, `app_role_screens`, `app_screens`
  (later migrations `010`/`018`/`019` seed the `reports.*` screen keys).
- Auth: `business-core/lambda/api/auth.py` — stdlib PBKDF2 hashing + HS256 JWT; signing key in Secrets
  Manager `iravi/dashboard/jwt`.
- Roles are **user-defined** (created in the Access Control UI), not a fixed Admin/Finance/Operations/Viewer
  set. Each role maps to a set of screen keys (`ui/src/screens.ts`).
- Enforcement: `POST /auth/login` + `/admin/*` are server-side enforced; read-only data endpoints are
  UI-only gated for now (backlog: per-route authorization).

---

## Dashboard Views (built — see `ui/`)

All main pages are implemented in the `ui/` project (default landing is **Overview**): Overview
(A-vs-B comparison + KPI tiles + customer ticker), Sales, Purchases, Current Stocks, Customer Ledger,
Customer Balances, Reports (Appendix-B, Ledger Statement, Monthly Sales, Customer/Supplier Balances FY),
Alerts (admin), and Admin → Access Control (RBAC). The original role-fixed view plan (Executive Summary /
Expense Tracker / Finance Overview) was superseded; Expenses remains a phase 3+ item.

---

## What Is Built

- [x] **Procurement Purchase Order (Bulk) + PDF export (2026-07-16):**
  `039_create_procurement_purchase_orders.sql` creates `procurement.purchase_orders` (per-day PO
  number `IAL/{fy}/seq` (fy = 4-digit FY code e.g. 2627; serial resets per FY); `fy` column + unique `(fy, po_seq)` + unique `po_no`; FKs to supplier_companies
  [supplier + bill-to + ship-to], technicals [product], signatory_authorities; quantity + unit
  KGS/LTRS, numeric rate + gst_rate (API returns computed amount/gst_amount/total_value),
  terms/dispatch/transport text, highlighted note; updated_at trigger);
  `040_add_procurement_purchase_order_screen.sql` seeds `procurement.purchase_orders` (sort_order 108).
  Added 5 routes (`/purchase-orders*` + `GET /purchase-orders/{id}/pdf`) to `local.procurement_routes`.
  **Reportlab reuse for PDF export:** the procurement Lambda now attaches a second layer —
  `reportlab_layer_arn` (new module var), wired in `procurement.tf` to the existing
  `aws_lambda_layer_version.alerts_evaluator_deps` (reportlab) so **no new CI layer step** is needed.
  Binary PDF served via the Lambda's `isBase64Encoded` response (HTTP API v2 decodes it). `terraform
  fmt` clean. Backs procurement_api `_po_*` / `po_pdf.py` + procurement-ui `PurchaseOrders.tsx`.
  **NOT yet applied to AWS** — apply 039 → 040 via psql over the SSM tunnel; admins then grant
  `procurement.purchase_orders` to roles in Access Control.

- [x] **Procurement Signatory Authority (2026-07-16):** `037_create_procurement_signatory_authorities.sql`
  creates `procurement.signatory_authorities` (`id`, `name` NOT NULL unique, `title`, `department`,
  `is_active`, updated_at trigger); `038_add_procurement_signatory_authority_screen.sql` seeds the
  `procurement.signatory_authorities` `app_screens` key (sort_order 107). Added 4 CRUD routes
  (`/signatory-authorities*`) to `local.procurement_routes` in the `production/procurement/` module
  (`terraform fmt` clean; the API Lambda auto-redeploys from source). Backs procurement_api
  `_signatories_*` + procurement-ui `SignatoryAuthorities.tsx`. **NOT yet applied to AWS** — apply
  037 → 038 via psql over the SSM tunnel; admins then grant the screen to roles in Access Control.

- [x] **Procurement Packaging Meta + Packaging Configuration (2026-07-16):**
  `033_create_procurement_packaging_meta.sql` creates `procurement.packaging_meta` (master size list —
  `unit_type` KG/LTR, `label`, `sort_order`, `is_active`, unique `(unit_type, label)`);
  `034_seed_procurement_packaging_meta.sql` seeds the 12 KG + 13 LTR unique sizes from
  `design/Opening Stock 15-Jul-2026.pdf` (labels verbatim, e.g. `100 GM (B)`, `1 LT`);
  `035_create_procurement_packagings.sql` creates `procurement.packagings` (brand→size: `technical_id`
  FK CASCADE + `packaging_meta_id` FK RESTRICT, unique `(technical_id, packaging_meta_id)`);
  `036_add_procurement_packaging_screens.sql` seeds `app_screens` keys `procurement.packaging_meta`
  (105) + `procurement.packagings` (106). Added 8 CRUD routes (`/packaging-meta*` + `/packagings*`) to
  `local.procurement_routes` in the `production/procurement/` module (`terraform fmt` clean; the
  procurement API Lambda auto-redeploys from source). Backs procurement_api `_packaging_meta_*` /
  `_packagings_*` + procurement-ui `PackagingMeta.tsx` / `Packagings.tsx`.
  **NOT yet applied to AWS** — apply 033 → 034 → 035 → 036 via psql over the SSM tunnel; admins then
  grant the two `procurement.*` screens to procurement roles in Access Control.

- [x] **DB migration 032 — procurement supplier-company address (2026-07-16):**
  `032_add_supplier_company_address.sql` adds nullable `address_line1/2/3`, `state`, `pin_code`,
  `gstin` columns to `procurement.supplier_companies` (additive `ALTER TABLE ... ADD COLUMN IF NOT
  EXISTS`; legacy `location` retained). Backs the extended Supplier Company Configuration screen
  (procurement_api `_companies_*` + procurement-ui). **NOT yet applied to AWS** — apply via psql
  over the SSM tunnel before the updated `procurement_api` Lambda serves the new fields. No
  Terraform change (the procurement API Lambda auto-redeploys from source on next apply).

- [x] **Procurement stack — segregated `production/procurement/` Terraform module (2026-07-13):**
  new folder `terraform/environments/production/procurement/` (`variables.tf` / `main.tf` /
  `outputs.tf`) instantiated from `procurement.tf` in the production root. Provisions the
  `procurement.iraviagrolife.com` stack: the `procurement_api` Lambda (source
  `business-core/lambda/procurement_api/`, reuses the shared `api_deps` psycopg2 layer — **no new CI
  layer step**, VPC private subnets + `sg_lambda`, env `DB_SECRET_ARN` + `JWT_SECRET_ARN`, IAM =
  VPCNetworking + Logs + SecretsManager on the db+jwt secrets only), its **own** API Gateway HTTP API
  (v2) with 22 routes (`/auth/*` + CRUD for technicals/supplier-companies/suppliers/enquiries/pdc) and
  CORS scoped to `https://procurement.iraviagrolife.com`, and its **own** Amplify app
  (`${project}-procurement-ui`, env var `VITE_API_BASE_URL` = the new stage URL). Root `procurement.tf`
  passes the shared VPC/subnets/SG, db+jwt secret ARNs, and the `api_deps` layer ARN into the module,
  and re-exports `procurement_api_endpoint` + `procurement_amplify_default_domain`. New vars
  `procurement_amplify_github_repo` + `procurement_domain` in `variables.tf`. `terraform fmt` clean.
  **One-time manual (mirrors the dashboard Amplify flow):** connect the `procurement-ui` repo in the
  Amplify console, `terraform import 'module.procurement.aws_amplify_app.procurement' <APP_ID>`, then
  apply; add the custom domain in the console + a CNAME at the DNS provider. **DB:** apply migrations
  026→027→028 via psql over the SSM tunnel BEFORE the procurement API serves data.
- [x] **DB migrations 026–028 (procurement, 2026-07-13)** — `026_create_procurement_schema.sql`
  creates `procurement` schema + `supplier_companies` / `technicals` / `suppliers` / `enquiries` /
  `pdc` (plain CRUD tables: `is_active` + `updated_at` trigger, NOT uni-temporal milestoning — this
  is hand-entered operational config, not an ETL snapshot feed); `027_add_procurement_screens.sql`
  seeds five `procurement.*` `app_screens` keys (shared RBAC — grant to procurement roles in Access
  Control); `028_seed_procurement_data.sql` idempotently seeds technicals/companies/suppliers/
  enquiries/PDC from `design/IAL Enquiry.xlsx`. **NOT yet applied to AWS** — apply 026→027→028 in
  order via psql over the SSM tunnel.

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
- [x] Terraform — `lambda_etl_stocks.tf` — stock balance ETL Lambda; `lambda_etl_sales.tf` bucket notification fans out to both Lambdas using non-overlapping suffixes (`).xlsx` for dated exports → etl_sales; `Stocks.xlsx` → etl_stocks). Phase 2 note (superseded): the fan-out is now **prefix-based** (each Lambda filters on a distinct `raw/<Prefix>`), all wired through the single shared `aws_s3_bucket_notification` in `lambda_etl_sales.tf`, with `eventbridge = true` added so `etl_supplier_ledger` can trigger off `raw/Ledger` via an EventBridge rule.
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
- [x] DB migrations — `010_add_customer_balances_fy_screen.sql` — idempotently inserts `app_screens` seed row `('reports.customer_balances_fy', 'Customer Balances (FY)', 90)` with `ON CONFLICT (screen_key) DO NOTHING`; RBAC key for the new Customer Balances (FY) report screen; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel
- [x] DB migrations — `011_add_customer_code_to_customer_details.sql` — adds `customer_code VARCHAR(20)` (nullable) to `customer_details` plus `idx_customer_details_code` index; sourced from the "General" sheet of the Customer Accounts Export File by `etl_customer_accounts`; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel (before the updated `etl_customer_accounts` Lambda ran)
- [x] DB migrations — `012_widen_customer_ledger_amount.sql` — widens `customer_ledger.amount` from `NUMERIC(15,2)` to `NUMERIC(15,4)`; the "Ledger All Accounts" export contains GST component lines at 3 decimal places (e.g. 6498.675) — storing at 2dp rounded them and produced a 1-paise drift when components were summed per voucher; schema.sql updated to match; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel, followed by a RE-INGEST of the ledger file(s) (rows stored before the widen were truncated and were recovered by re-ingest) and a Redis cache flush
- [x] DB migrations — `013_create_alerts.sql` — creates `alerts`, `alert_conditions`, `alert_recipients`, `alert_runs` tables with check constraints; all relational (no JSONB); schema.sql updated to match; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel
- [x] Terraform — `ses.tf` — SES domain identity for `var.alerts_domain` (default `iraviagrolife.com`) + DKIM configuration; outputs `ses_domain_verification_token`, `ses_dkim_tokens` (3 CNAMEs), `ses_identity_arn`; `aws_ses_configuration_set` named `${project}-alerts`; two manual steps required: (a) add DNS records, (b) request SES production access
- [x] Terraform — `lambda_alerts_evaluator.tf` — Alerts Evaluator Lambda (`python3.12`, handler `handler.lambda_handler`, 256 MB, 300 s timeout); reuses `api_deps` layer (psycopg2); VPC private subnets + sg_lambda; env: `DB_SECRET_ARN`, `ALERTS_SENDER_EMAIL`; IAM: GetSecretValue on DB secret + ses:SendEmail/SendRawEmail; EventBridge schedule changed from daily `cron(30 5 * * ? *)` (11:00 IST) to `rate(15 minutes)` — send time is now per-alert (`alerts.schedule_time`); business-core Lambda self-selects which alerts are due each invocation. **SES IAM scoping fix (2026-06-25):** `Resource` in the SES statement was broadened from the domain identity ARN alone to a two-element list — `[aws_ses_domain_identity.alerts.arn, "arn:aws:ses:<region>:<account>:identity/*"]` — because SES authorises `SendEmail` against the *sender* identity ARN, and an address-level verified identity (e.g. `kranthi@iraviagrolife.com`) resolves to `identity/kranthi@iraviagrolife.com`, not `identity/iraviagrolife.com`; the domain-only scope caused `AccessDenied`.
- [x] DB migrations — `014_add_alert_schedule_time.sql` — adds `schedule_time TIME NOT NULL DEFAULT '11:00:00'` to `alerts` table; default preserves legacy 11:00 IST behaviour for existing rows; schema.sql updated to match; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel
- [x] Terraform — `lambda_api.tf` alerts routes — `GET /alerts`, `POST /alerts`, `PUT /alerts/{id}`, `DELETE /alerts/{id}`, `GET /alerts/fields`, `POST /alerts/{id}/test` added to `api_rbac_routes` local; enforced in Lambda handler (valid JWT + is_admin); CORS already covers all methods via existing cors_configuration block
- [x] DB migrations — `015_add_alert_branch.sql` — adds nullable `branch VARCHAR(100)` column to `alerts` table; scopes sales/sale_returns category alerts to a specific branch (NULL or 'ALL' = all branches; balances alerts ignore this column); schema.sql updated to match; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel; alerts_evaluator branch-filter logic lives in business-core (no IaC Lambda change required — redeploys on next apply)
- [x] DB migrations — `016_create_supplier_accounts.sql` — creates `supplier_accounts` table (uni-temporal milestoned, natural key `name`, BIGSERIAL PK); partial unique index `uix_supplier_accounts_active` enforces one active row per supplier name; schema.sql updated to match; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel after terraform apply has provisioned `lambda_etl_supplier_accounts`
- [x] Terraform — `lambda_etl_supplier_accounts.tf` — Supplier Accounts ETL Lambda (`python3.12`, handler `handler.lambda_handler`, 256 MB, 120 s); own pip layer at `.lambda_layers/etl_supplier_accounts/`; IAM: VPCNetworking + Logs + SecretsManager(db) + S3 Get/Put/Delete + ListBucket; env: DATA_BUCKET, DB_SECRET_ARN; VPC private subnets + sg_lambda; source: `business-core/lambda/etl_supplier_accounts/`; business-core must be pushed BEFORE this repo is planned/applied
- [x] Terraform — `lambda_etl_sales.tf` shared S3 bucket notification extended — added `lambda_function` block for `etl_supplier_accounts` with prefix `raw/Supplier` and suffix `.xlsx`; `aws_lambda_permission.s3_invoke_etl_supplier_accounts` added to `depends_on`; no new `aws_s3_bucket_notification` resource created (single-resource-per-bucket rule preserved)
- [x] CI — `.github/workflows/terraform.yml` — "Build etl_supplier_accounts layer" pip-install step added to BOTH the plan job AND the apply job; installs into `.lambda_layers/etl_supplier_accounts/python/` with linux-compatible wheels
- [x] DB migrations — `017_create_supplier_ledger.sql` — creates `supplier_ledger` table (identical shape to `customer_ledger`, uni-temporal milestoned, natural key `(transaction_date, voucher_no, account_name, category, sub_category)`); same indexes pattern; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel
- [x] Terraform — `lambda_etl_supplier_ledger.tf` — Supplier Ledger ETL Lambda (`python3.12`, 512 MB, 300 s); own pip layer at `.lambda_layers/etl_supplier_ledger/`; IAM: VPCNetworking + Logs + SecretsManager(db) + S3 **read-only** (`s3:GetObject` on bucket/* and `s3:ListBucket` on bucket arn — no PutObject, no DeleteObject, no events:PutEvents); env: DATA_BUCKET, DB_SECRET_ARN, RAW_PREFIX, PROCESSED_PREFIX; VPC private subnets + sg_lambda; triggered via EventBridge "Object Created" rule (NOT an S3 notification — avoids the overlapping-prefix conflict with etl_customer_ledger); source: `business-core/lambda/etl_supplier_ledger/`
- [x] Terraform — `lambda_etl_sales.tf` `aws_s3_bucket_notification.etl_trigger` — added `eventbridge = true` (single additive line); enables S3 to forward all object events to EventBridge so the new `s3_ledger_object_created` rule in `lambda_etl_supplier_ledger.tf` fires; no existing `lambda_function {}` blocks were touched
- [x] CI — `.github/workflows/terraform.yml` — "Build etl_supplier_ledger layer" pip-install step added to BOTH the plan job AND the apply job; installs into `.lambda_layers/etl_supplier_ledger/python/` with linux-compatible wheels
- [x] Terraform — `lambda_api.tf` updated — `GET /reports/supplier-balances-fy` route added (`aws_apigatewayv2_route.reports_supplier_balances_fy`); same explicit per-path route pattern as `reports_customer_balances_fy`; CORS already covers GET via the existing `cors_configuration` block — no CORS change needed; data report routes are NOT listed in `api_rbac_routes` (only /auth, /admin, /alerts live there) so no change to that local
- [x] DB migrations — `018_add_supplier_balances_fy_screen.sql` — idempotently inserts `app_screens` seed row `('reports.supplier_balances_fy', 'Supplier Balances (FY)', 91)` with `ON CONFLICT (screen_key) DO NOTHING`; RBAC key for the new Supplier Balances (FY) report screen; mirrors `010_add_customer_balances_fy_screen.sql`; `db/schema.sql` seeded `app_screens` block updated to include sort_order 91 row for consistency; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel; admins must then map `reports.supplier_balances_fy` to roles via the Access Control screen in the dashboard
- [x] Terraform — `lambda_api.tf` updated — `GET /reports/monthly-sales` route added (`aws_apigatewayv2_route.reports_monthly_sales`); same explicit per-path route pattern as `reports_customer_balances_fy` and `reports_supplier_balances_fy`; CORS already covers GET via the existing `cors_configuration` block — no CORS change needed; public data route — NOT listed in `api_rbac_routes` (only /auth, /admin, /alerts live there)
- [x] Terraform — `lambda_api.tf` updated (2026-07-11) — Supplier Ledger statement route `GET /supplier-ledger/statement` (`aws_apigatewayv2_route.supplier_ledger_statement`) added; same explicit per-path pattern; CORS covered by existing GET block; public data route. Feeds the Reports → Supplier Ledger statement screen (business-core `_handle_supplier_ledger_statement`, reading `supplier_ledger` for one account)
- [x] DB migrations — `021_add_supplier_ledger_statement_screen.sql` (2026-07-11) — idempotently inserts `app_screens` seed `('reports.supplier_ledger_statement', 'Supplier Ledger', 94)` with `ON CONFLICT DO NOTHING`; RBAC key for the new Supplier Ledger statement report (Reports section; supplier-side counterpart to `reports.ledger_statement`); **NOT yet applied to AWS** — apply manually via psql over the SSM tunnel, then map to roles via Access Control
- [x] Terraform — `lambda_api.tf` updated (2026-07-11) — Supplier Aging routes added: `GET /supplier-ledger/range` (`aws_apigatewayv2_route.supplier_ledger_range`), `GET /supplier-ledger` (`aws_apigatewayv2_route.supplier_ledger`), `GET /suppliers/details` (`aws_apigatewayv2_route.suppliers_details`); same explicit per-path route pattern as the other data routes; CORS already covers GET via the existing `cors_configuration` block — no CORS change; public data routes — NOT in `api_rbac_routes`. These feed the UI's client-side Supplier Balances (aging) screen (business-core handlers `_handle_supplier_ledger_range` / `_handle_supplier_ledger_data` / `_handle_supplier_details`, reading `supplier_ledger` + `supplier_accounts`)
- [x] DB migrations — `020_add_supplier_balances_screen.sql` (2026-07-11) — idempotently inserts `app_screens` seed row `('supplier_balances', 'Supplier Balances', 93)` with `ON CONFLICT (screen_key) DO NOTHING`; RBAC key for the new Supplier Balances aging screen (Suppliers nav section; supplier-side counterpart to the customer `balances` screen); mirrors `010`/`018`/`019`; **NOT yet applied to AWS** — apply manually via psql over the SSM tunnel, then admins map `supplier_balances` to roles via Access Control
- [x] DB migrations — `019_add_monthly_sales_screen.sql` — idempotently inserts `app_screens` seed row `('reports.monthly_sales', 'Monthly Sales', 92)` with `ON CONFLICT (screen_key) DO NOTHING`; RBAC key for the new Monthly Sales report screen; mirrors `010` and `018`; `db/schema.sql` seeded `app_screens` block updated to include sort_order 92 row for consistency; APPLIED to AWS (2026-07-11) via psql over the SSM tunnel; admins must then map `reports.monthly_sales` to roles via the Access Control screen in the dashboard
- [x] Terraform — `lambda_alerts_evaluator.tf` updated — added `aws_lambda_layer_version.alerts_evaluator_deps` (`${var.project}-alerts-evaluator-deps`) built from `.lambda_layers/alerts_evaluator_deps/python/` via `archive_file` + `filemd5` pattern; `alerts_evaluator` Lambda's `layers` now lists BOTH `api_deps.arn` (psycopg2 — retained) AND `alerts_evaluator_deps.arn` (reportlab — for Monthly Sales PDF email attachments); no IAM change (ses:SendRawEmail already granted)
- [x] CI — `.github/workflows/terraform.yml` — "Build alerts_evaluator_deps layer" pip-install step added to BOTH the plan job AND the apply job; installs `reportlab` into `.lambda_layers/alerts_evaluator_deps/python/` with `--platform manylinux2014_x86_64 --only-binary=:all:` Linux-compatible wheels; business-core must be pushed first (Terraform evaluates `archive_file` source path at validate time)

**Stocks pipeline is complete end-to-end.** Current Stocks UI is built and ready to deploy. Redis cache is populated nightly by redis_updater after `ETLStocksSuccess` event.

**Redis key schema (stocks):**
- `iravi:stocks:summary` — `{total_kgs, total_vols, stock_valuation, total_products, as_of, updated_at}`, 24h TTL
- `iravi:stocks:current` — JSON array of all active `snapshot_stock` rows, 24h TTL
- Unit classification for tiles: packing_size scanned for `KG|GMS|GM` (weight) vs `LTR|LT|ML|L` (volume) using Python regex

**UI stack decision:** Vite + React + TypeScript + Tailwind CSS. No shadcn/ui dependency — components written in plain Tailwind. Client-side filtering/sorting on the ~500-row dataset (no extra API calls needed).

## What Is Next (build in this order)

- [x] **Deploy Terraform** — `elasticache.tf` + Lambda configs applied via GitHub Actions; `elasticache_host` output captured
- [x] **Deploy UI** — `ui/` connected to AWS Amplify Hosting; `VITE_API_BASE_URL` set from `terraform output api_endpoint`
- [x] **Test stocks flow end-to-end** — stocks pipeline confirmed complete end-to-end (see "What Is Built")
- [x] **Implement etl_customer_ledger handler** — done (`customer_ledger` ETL complete, unitemporal milestoning, emits `ETLCustomerLedgerSuccess`)

- [ ] **Implement etl_sales handler** — parse `RGF Sales Book*.xlsx` (skip rows 1–5, detect total rows); upsert `dim_customers` + `fact_sales`; emit `ETLSalesSuccess`; move file to `processed/` (still a stub)
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
- [x] iravi-ui: Alerts admin screen built (`ui/src/pages/Alerts/AlertsList.tsx` + `AlertBuilder.tsx`) — wired to `GET/POST/PUT/DELETE /alerts`, `GET /alerts/fields`, `POST /alerts/{id}/test`; `schedule_time` exposed as a time-picker

---

## Key Technical Choices

| Decision | Choice | Reason |
|---|---|---|
| Language (Lambdas) | Python 3.12 | Faster to write ETL/data code, openpyxl for Excel parsing |
| DB driver | psycopg2 | Standard PostgreSQL driver for Python |
| Excel parsing | openpyxl | Handles .xlsx, reads cell values cleanly |
| Redis client | redis-py | Standard Python Redis client |
| IaC | Terraform | Reproducible, version-controlled |
| Auth | App-level JWT/RBAC (DB users, PBKDF2 + HS256) | Fine-grained per-screen roles managed in-app; Cognito on API Gateway deferred to phase 3 |
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
