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
| Schema Runner | One-time Lambda to apply `db/schema.sql` against RDS — reusable for future migrations |
| Bastion Host | `t3.micro` EC2 in public subnet — SSH tunnel entry point for SQL client access to RDS |
| CI/CD | GitHub Actions — fmt + validate on PR (Stage 1); plan + apply coming after AWS account setup |
| Diagram | Visual architecture diagram — `design/aws-architecture-diagram.html` (git-ignored, local only) |
| Setup Guide | AWS account setup guide — `design/aws-account-setup-guide.html` (git-ignored, local only) |

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

Go to Repo → Settings → Secrets and variables → Actions → New repository secret. Add all 4:

| Secret name | Value | Purpose |
|---|---|---|
| `AWS_ROLE_ARN` | ARN of `terraform-deployer` role | Used by the pipeline OIDC step to assume the IAM role and authenticate with AWS |
| `TF_VAR_alert_email` | your email address | Terraform `alert_email` variable — SNS subscription for CloudWatch alarms |
| `TF_VAR_bastion_key_name` | `iravi-dashboard-bastion` | Terraform `bastion_key_name` variable — EC2 Key Pair attached to the bastion host |
| `TF_VAR_bastion_allowed_cidr` | your public IPv4 + `/32` (run `curl https://api4.ipify.org`) | Terraform `bastion_allowed_cidr` variable — only this IP can SSH into the bastion on port 22 |

> **Why `TF_VAR_*` secrets?** `terraform.tfvars` is git-ignored so the pipeline can't read it. Terraform automatically maps any environment variable prefixed with `TF_VAR_` to the matching input variable — these secrets are the pipeline equivalent of `terraform.tfvars`.

> **If your IP changes:** Update `TF_VAR_bastion_allowed_cidr` in GitHub secrets and re-run the pipeline — it updates the security group rule in seconds.

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
            └── schema_runner.tf
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

### Step 4 — Check the latest PostgreSQL version (optional but recommended)

The RDS instance is pinned to `16.3` in `rds.tf`. Verify the latest available minor version before applying:

```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --query 'DBEngineVersions[?starts_with(EngineVersion, `16`)].EngineVersion' \
  --output table
```

Update `engine_version` in `rds.tf` if a newer minor version is available.

---

### Step 5 — Deploy infrastructure

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
vpc_id              = "vpc-xxxxxxxxxxxxxxxxx"
private_subnet_ids  = ["subnet-xxx", "subnet-yyy"]
sg_lambda_id        = "sg-xxxxxxxxxxxxxxxxx"   ← attach to all Lambda functions
sg_elasticache_id   = "sg-xxxxxxxxxxxxxxxxx"   ← attach to ElastiCache cluster
db_secret_arn       = "arn:aws:secretsmanager:..."
sns_alerts_arn      = "arn:aws:sns:..."
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

Upload `schema.sql` to S3, then invoke the Schema Runner Lambda to apply it against RDS.

```bash
# From the IaC repo root

# 1. Get the state bucket name
BUCKET=$(cd terraform/environments/production && terraform output -raw state_bucket_name)

# 2. Upload the schema file
aws s3 cp db/schema.sql s3://$BUCKET/schema/schema.sql

# 3. Invoke the schema runner Lambda
aws lambda invoke \
  --function-name iravi-dashboard-schema-runner \
  --payload '{}' \
  response.json

cat response.json
# Expected: {"status": "ok"}
```

If there's an error, check the Lambda logs:

```bash
aws logs tail /aws/lambda/iravi-dashboard-schema-runner --follow
```

---

## Connecting to RDS with a SQL Client

RDS is in a private subnet with no public IP. Connect via SSH tunnel through the bastion host.

### Before first connection (one-time setup)

**1. Create an SSH key pair in AWS Console**
- Console → EC2 → Key Pairs → Create key pair
- Name: `iravi-dashboard-bastion`, Format: `.pem`
- Download and store the `.pem` file — you cannot download it again

**2. Find your public IP and set it in tfvars**
```bash
curl https://ifconfig.me
# e.g. 203.0.113.45  →  set bastion_allowed_cidr = "203.0.113.45/32"
```

**3. After `terraform apply`, get the bastion IP**
```bash
terraform output bastion_public_ip
```

### Connecting via pgAdmin

1. Add New Server → **SSH Tunnel** tab:

| Field | Value |
|---|---|
| Tunnel host | `bastion_public_ip` from `terraform output` |
| Tunnel port | `22` |
| Username | `ec2-user` |
| Identity file | path to your `.pem` file |

2. **Connection** tab:

| Field | Value |
|---|---|
| Host | RDS endpoint — `terraform output rds_endpoint` |
| Port | `5432` |
| Database | `iravi_dashboard` |
| Username | `dashboard_admin` |
| Password | from AWS Console → Secrets Manager → `iravi/dashboard/db` |

### Connecting via DBeaver / TablePlus

Same values — look for **SSH Tunnel** or **SSH** section in the connection settings and fill in the same fields as above.

### If your IP changes

Update `bastion_allowed_cidr` in `terraform.tfvars` and run `terraform apply` — it updates the security group rule in seconds.

---

## Applying Future Schema Changes

The Schema Runner Lambda is kept in place for this purpose.
When a schema change is needed (e.g. adding a column to `fact_expenses`):

1. Update `db/schema.sql` with the change (use `ALTER TABLE`, not full DDL)
2. Upload and invoke:

```bash
# From the IaC repo root
BUCKET=$(cd terraform/environments/production && terraform output -raw state_bucket_name)
aws s3 cp db/schema.sql s3://$BUCKET/schema/schema.sql
aws lambda invoke \
  --function-name iravi-dashboard-schema-runner \
  --payload '{}' \
  response.json && cat response.json
```

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

**Schema runner Lambda errors with connection timeout (RDS)**
→ The Lambda is in the VPC's private subnets. Confirm `sg_lambda_id` allows outbound TCP 5432 to `sg_rds_id`. Check `terraform output` to verify SG IDs match what's in the Lambda config.

**Lambda times out reaching Secrets Manager**
→ The Secrets Manager Interface endpoint requires its own SG (`sg-vpc-endpoints`) with an inbound 443 rule from `sg_lambda_id`. Verify the `vpc_endpoints` SG exists and its ingress rule references the Lambda SG.

**Schema runner errors with `relation already exists`**
→ The schema was already applied. This is safe — re-running is idempotent for `CREATE TABLE IF NOT EXISTS`. If you used plain `CREATE TABLE`, wrap DDL statements with `IF NOT EXISTS`.

**SNS email not arriving**
→ Check your spam folder. The sender is `no-reply@sns.amazonaws.com`. Subscription stays in `PendingConfirmation` state until confirmed.
