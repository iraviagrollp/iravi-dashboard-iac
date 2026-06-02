# ── Bastion Host ──────────────────────────────────────────────────────────────
# Connects to RDS via AWS Systems Manager Session Manager port forwarding.
# No SSH port, no key pair, no IP allowlist needed.
#
# Usage (after terraform apply):
#   1. Install AWS CLI and the Session Manager plugin:
#      https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
#
#   2. Start a port-forwarding session to RDS (run this locally):
#      aws ssm start-session \
#        --target <bastion_instance_id from terraform output> \
#        --document-name AWS-StartPortForwardingSessionToRemoteHost \
#        --parameters '{"host":["<rds-endpoint>"],"portNumber":["5432"],"localPortNumber":["5432"]}'
#
#   3. Connect pgAdmin / DBeaver to localhost:5432
#      Credentials: AWS Console -> Secrets Manager -> iravi/dashboard/db -> Retrieve secret value
# -----------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Bastion Security Group ────────────────────────────────────────────────────

resource "aws_security_group" "bastion" {
  name        = "${var.project}-sg-bastion"
  description = "Bastion host - HTTPS outbound for SSM, PostgreSQL outbound to RDS"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-sg-bastion" }
}

resource "aws_security_group_rule" "bastion_to_rds" {
  type                     = "egress"
  description              = "PostgreSQL to RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.rds.id
}

resource "aws_security_group_rule" "bastion_to_elasticache" {
  type                     = "egress"
  description              = "Redis to ElastiCache"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.elasticache.id
}

resource "aws_security_group_rule" "bastion_https_outbound" {
  type              = "egress"
  description       = "HTTPS outbound for SSM agent and OS updates"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.bastion.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── RDS - allow inbound from bastion ─────────────────────────────────────────

resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  description              = "PostgreSQL from bastion"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.bastion.id
}

# ── ElastiCache - allow inbound from bastion ──────────────────────────────────

resource "aws_security_group_rule" "elasticache_from_bastion" {
  type                     = "ingress"
  description              = "Redis from bastion (SSM port-forwarding for local inspection)"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.elasticache.id
  source_security_group_id = aws_security_group.bastion.id
}

# ── IAM Role for SSM ──────────────────────────────────────────────────────────

resource "aws_iam_role" "bastion" {
  name = "${var.project}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ── Bastion EC2 Instance ──────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project}-bastion" }
}
