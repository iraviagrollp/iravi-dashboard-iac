# Security groups are created without inline rules to avoid the Terraform
# circular-dependency problem (Lambda SG ↔ RDS SG reference each other).
# Rules are added as separate aws_security_group_rule resources below.

# ── Lambda ────────────────────────────────────────────────────────────────────

resource "aws_security_group" "lambda" {
  name        = "${var.project}-sg-lambda"
  description = "Attached to all Lambda functions (ETL, Redis Updater, API)"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-sg-lambda" }
}

resource "aws_security_group_rule" "lambda_to_rds" {
  type                     = "egress"
  description              = "PostgreSQL to RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda.id
  source_security_group_id = aws_security_group.rds.id
}

resource "aws_security_group_rule" "lambda_to_elasticache" {
  type                     = "egress"
  description              = "Redis to ElastiCache"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda.id
  source_security_group_id = aws_security_group.elasticache.id
}

resource "aws_security_group_rule" "lambda_to_https" {
  type              = "egress"
  description       = "HTTPS to VPC endpoints and internet (SNS, CloudWatch, S3)"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lambda.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── RDS ───────────────────────────────────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.project}-sg-rds"
  description = "RDS PostgreSQL — inbound from Lambda only"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-sg-rds" }
}

resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  description              = "PostgreSQL from Lambda"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
}

# ── ElastiCache ───────────────────────────────────────────────────────────────

resource "aws_security_group" "elasticache" {
  name        = "${var.project}-sg-elasticache"
  description = "ElastiCache Redis — inbound from Lambda only"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-sg-elasticache" }
}

resource "aws_security_group_rule" "elasticache_from_lambda" {
  type                     = "ingress"
  description              = "Redis from Lambda"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticache.id
  source_security_group_id = aws_security_group.lambda.id
}

# ── VPC Interface Endpoints ───────────────────────────────────────────────────
# Dedicated SG for Interface endpoint ENIs. The endpoint's SG evaluates inbound
# traffic from clients — without an ingress rule here, Lambda's connection
# attempts to the endpoint ENI are dropped even though Lambda has outbound 443.

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-sg-vpc-endpoints"
  description = "VPC Interface endpoint ENIs — inbound HTTPS from Lambda only"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-sg-vpc-endpoints" }
}

resource "aws_security_group_rule" "vpc_endpoints_from_lambda" {
  type                     = "ingress"
  description              = "HTTPS from Lambda"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints.id
  source_security_group_id = aws_security_group.lambda.id
}
