# ── Bastion Host ──────────────────────────────────────────────────────────────
# Jump server in the public subnet — used to tunnel into RDS from pgAdmin,
# DBeaver, TablePlus, or any other SQL client via SSH tunnel.
#
# Before running terraform apply:
#   1. Go to AWS Console → EC2 → Key Pairs → Create key pair
#      Name it "iravi-dashboard-bastion", format: .pem, then download it.
#      Store the .pem file safely — AWS will not let you download it again.
#   2. Find your current public IP:
#      curl https://ifconfig.me   →  e.g. 203.0.113.45
#      Then set bastion_allowed_cidr = "203.0.113.45/32" in terraform.tfvars
#   3. Set bastion_key_name = "iravi-dashboard-bastion" in terraform.tfvars
# ─────────────────────────────────────────────────────────────────────────────

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
  description = "Bastion host — SSH inbound from allowed IP, PostgreSQL outbound to RDS"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.project}-sg-bastion" }
}

# SSH locked to your IP only — never open port 22 to 0.0.0.0/0
resource "aws_security_group_rule" "bastion_ssh_inbound" {
  type              = "ingress"
  description       = "SSH from operator IP only"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.bastion.id
  cidr_blocks       = [var.bastion_allowed_cidr]
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

resource "aws_security_group_rule" "bastion_https_outbound" {
  type              = "egress"
  description       = "HTTPS outbound for OS package updates"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.bastion.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# ── RDS — allow inbound from bastion ─────────────────────────────────────────

resource "aws_security_group_rule" "rds_from_bastion" {
  type                     = "ingress"
  description              = "PostgreSQL from bastion"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.bastion.id
}

# ── Bastion EC2 Instance ──────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = var.bastion_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.project}-bastion" }
}
