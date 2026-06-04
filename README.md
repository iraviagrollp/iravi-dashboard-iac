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
| CI/CD | GitHub Actions — fmt + validate on PR (Stage 1); plan + apply coming after AWS account setup |
| Diagram | Visual architecture diagram — `design/aws-architecture-diagram.html` (git-ignored, local only) |
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
│       └── 003_add_voucher_no_to_customer_ledger.sql
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
            ├── lambda_etl_sales.tf          ← ETL sales Lambda + shared S3 bucket notification (fans out to etl_sales, etl_stocks, etl_customer_ledger)
            ├── lambda_etl_stocks.tf         ← Stock balance ETL Lambda
            ├── lambda_etl_customer_ledger.tf← Customer ledger ETL Lambda (trigger: raw/Ledger*.xlsx)
            ├── lambda_redis_updater.tf      ← Redis updater + EventBridge rule
            ├── lambda_api.tf               ← API Lambda + API Gateway HTTP API
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

Edit `terraform.tfvars` — the only required field is `alert_email`:

```hcl
aws_region   = "ap-south-1"
environment  = "production"
alert_email  = "your-email@example.com"   # ← alerts go here
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
terraform plan    # review — expect ~25 resources to be created
terraform apply
```

`terraform apply` takes **8–12 minutes**, most of which is waiting for RDS to become available.

> **Expected resource count:** ~27 resources. The extra 2 vs. earlier estimates are the dedicated VPC endpoint security group and its ingress rule.

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
