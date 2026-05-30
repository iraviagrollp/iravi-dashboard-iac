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
│   │   └── schema.mmd                  ← Mermaid class diagram of schema
│   ├── design/
│   │   ├── stakeholder-presentation.html
│   │   ├── aws-architecture-diagram.html
│   │   ├── aws-account-setup-guide.html
│   │   └── bastion-rds-connection-guide.html  ← SSM port forwarding + schema runner guide
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
│               ├── secrets.tf          ← Secrets Manager (DB credentials)
│               ├── monitoring.tf       ← SNS + 5 CloudWatch alarms
│               ├── schema_runner.tf    ← removed (apply schema via SSM + psql)
│               ├── bastion.tf          ← Bastion EC2 — SSM Session Manager, no SSH
│               ├── lambda_etl_sales.tf ← ETL Lambda + S3 trigger (Phase 1); bucket notification shared with etl_stocks
│               ├── lambda_etl_stocks.tf ← Stock balance ETL Lambda (S3 trigger piggybacked on etl_sales notification)
│               ├── lambda_redis_updater.tf ← Redis Updater + EventBridge trigger
│               └── lambda_api.tf       ← API Lambda + API Gateway HTTP API
├── business-core\                      ← separate repo (processing logic)
│   ├── CLAUDE.md
│   └── lambda\
│       ├── etl_sales\                  ← Phase 1 active build target
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
| `fact_sales` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `fact_sales_returns` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `fact_purchases` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `fact_purchase_returns` | Fact (daily append) | `(voucher_no, transaction_date, product_name)` |
| `fact_expenses` | Fact (daily append) | `(voucher_no, transaction_date)` |
| `snapshot_stock` | Snapshot (replace per date) | `(snapshot_date, product_brand_name, packing_id)` |
| `snapshot_stock_margin` | Snapshot (replace per date) | `(snapshot_date, product_brand_name, packing_id)` |
| `snapshot_customer_balances` | Snapshot (replace per date) | `(snapshot_date, branch, customer_name)` |
| `etl_runs` | Audit | `run_date` |

### Key schema decisions
- `source_date` was **removed** — lineage tracked via `ingested_at` + `etl_runs.files_processed`
- `dim_packings` normalises packing strings (`10x1 KG`, `20x500 GM`, etc.) — `snapshot_stock` and `snapshot_stock_margin` reference via `packing_id` FK
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
| `sg_elasticache_id` | ElastiCache — inbound from Lambda SG only |
| `sg_vpc_endpoints` | VPC Interface endpoint ENIs — inbound 443 from Lambda SG only |
| `sg_bastion` | Bastion EC2 — outbound 443 (SSM) + outbound 5432 to RDS. No inbound rules. |

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

`terraform.tfvars` is git-ignored. The pipeline reads these secrets as `TF_VAR_*` env vars instead — Terraform maps them automatically to the matching input variables.

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
- [x] AWS account setup guide (`design/aws-account-setup-guide.html`)
- [x] AWS Account + OIDC setup — account live, `terraform-deployer` role created, pipeline stages 2 & 3 enabled, `terraform apply` run, all infra provisioned
- [x] File Sync Agent — deployed and running on FUSIL PRO server · `D:\Projects\Iravi\FileSyncAgent\`
- [x] business-core project created — `D:\Projects\Iravi\business-core\` with lambda scaffolds for etl_sales, redis_updater, api
- [x] Terraform — Lambda resources (`lambda_etl_sales.tf`, `lambda_redis_updater.tf`, `lambda_api.tf`) with IAM, triggers, API Gateway
- [x] Terraform — `lambda_etl_stocks.tf` — stock balance ETL Lambda; `lambda_etl_sales.tf` bucket notification extended to fan-out to both etl_sales and etl_stocks

## Strategy: Sales-First End-to-End

**Decision (2026-05-26):** Build the full pipeline end-to-end for sales data only before expanding to other data types. Goal is to get comfortable with the complete flow (S3 → ETL → DB → Redis → API → UI) and give the team time to validate before adding purchases, stock, expenses, etc.

Scope for this phase:
- File: `RGF Sales Book*.xlsx` only
- Table: `fact_sales` + `dim_customers` (FK dependency)
- Trigger: direct S3 `ObjectCreated` event on the sales file (no manifest needed for single-file flow)
- API: `/sales` endpoint only
- UI: Sales Analytics view only

## What Is Next (build in this order)

- [ ] **ElastiCache Redis** — add Terraform in `environments/production/`
  - Engine: Redis 7.x
  - Node: `cache.t3.micro`
  - Subnet group using existing private subnets
  - Security group: `sg_elasticache_id` (already created)

- [ ] **ETL Lambda — Sales only (Phase 1)**
  - Runtime: Python 3.12
  - Triggered by S3 `ObjectCreated` on `RGF Sales Book*.xlsx` (no manifest — single file)
  - Parses sales file: skip rows 1–5, detect/skip total rows
  - Columns: `Date, Voucher No, Branch, Party, Party GSTN, Qty, Gross, Disc, AV, CGST, SGST, IGST, Net, BillValue`
  - Upserts `dim_customers` (on `customer_name`) then `fact_sales` (on `voucher_no, transaction_date`)
  - Writes success/failure to `etl_runs`
  - Emits EventBridge event on success → triggers Redis Updater
  - Moves file from `raw/` to `processed/` on success
  - Attach: `sg_lambda_id`, `private_subnet_ids`, `db_secret_arn`
  - Expand to all 8 file types in Phase 2

- [ ] **Redis Updater Lambda**
  - Triggered by ETL success EventBridge event
  - Reads key metrics from Dashboard DB
  - Writes to ElastiCache with 7-day TTL
  - Key schema: `dashboard:{view}:{date}`

- [ ] **API Layer — Sales only (Phase 1)**
  - API Gateway + Lambda (Python 3.12)
  - Cognito JWT authoriser
  - RBAC middleware: decode JWT → check Cognito group → enforce access
  - Cache-aside: Redis fast path → Dashboard DB fallback → populate Redis
  - Endpoint: `/sales` only — expand to full endpoint set in Phase 2

- [ ] **Cognito** — add Terraform
  - User pool + App Client
  - Groups: `admin`, `finance`, `operations`, `viewer`

- [ ] **Dashboard UI — Sales Analytics view (Phase 1)**
  - React + AWS Amplify
  - Cognito hosted login
  - Sales Analytics view only — expand to all 6 views in Phase 2

- [ ] **One-time historical migration**
  - Export 1 month of transaction files from FUSIL PRO
  - Run through ETL Lambda manually (or batch script)
  - Stock history: not available — starts from go-live

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
