# VPC Endpoints keep traffic for S3 and Secrets Manager inside the AWS
# network — reducing NAT Gateway data charges and improving security.

# ── S3 Gateway Endpoint (free) ────────────────────────────────────────────────
# Routes S3 traffic from private subnets through AWS backbone, not NAT Gateway.
# Lambda reads export files from S3 without touching the internet.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "${var.project}-vpce-s3" }
}

# ── Secrets Manager Interface Endpoint ────────────────────────────────────────
# Lambda fetches DB credentials from Secrets Manager without leaving the VPC.

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project}-vpce-secretsmanager" }
}
