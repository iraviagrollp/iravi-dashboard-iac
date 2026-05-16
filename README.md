# IRAVI AGRO LIFE LLP — Admin Dashboard Infrastructure

Terraform-managed AWS infrastructure for the Admin Dashboard project.
Region: `ap-south-1` (Mumbai).

---

## What This Provisions

| Layer | Resource |
|---|---|
| Network | VPC, 2 public + 2 private subnets, Internet Gateway, NAT Gateway |
| Security | 4 security groups (Lambda, RDS, ElastiCache, VPC Endpoints) with scoped rules |
| VPC Endpoints | S3 gateway (free), Secrets Manager interface (dedicated endpoint SG) |
| Database | RDS PostgreSQL 16 — `db.t3.small`, 20 GB gp3, encrypted |
| Credentials | AWS Secrets Manager secret with DB host/port/name/user/password |
| Monitoring | SNS alert topic + 5 CloudWatch alarms (CPU, storage, connections, memory, write latency) |
| Schema Runner | One-time Lambda to apply `db/schema.sql` against RDS — reusable for future migrations |

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

| Resource | Monthly |
|---|---|
| RDS db.t3.small (single-AZ, 20 GB gp3) | ~$25–30 |
| NAT Gateway (1 AZ) + data | ~$35–45 |
| Secrets Manager interface VPC endpoint | ~$8 |
| CloudWatch alarms + logs | ~$2 |
| S3 (state bucket, exports) | < $1 |
| **Total** | **~$70–85/mo** |

> The NAT Gateway is the largest cost. It can be reduced by adding VPC endpoints for services Lambda calls frequently (already done for S3 and Secrets Manager).

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
