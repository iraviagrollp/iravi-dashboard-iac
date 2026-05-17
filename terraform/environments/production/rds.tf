# ── DB Subnet Group ───────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project}-db-subnet-group" }
}

# ── Parameter Group ───────────────────────────────────────────────────────────
# Forces SSL on all connections. Any client that connects without SSL is rejected.

resource "aws_db_parameter_group" "postgres16" {
  name   = "${var.project}-postgres16"
  family = "postgres16"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }

  tags = { Name = "${var.project}-postgres16-params" }
}

# ── Password (generated, stored in Secrets Manager — never in tfvars) ─────────

resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
}

# ── RDS Instance ──────────────────────────────────────────────────────────────
# Check the latest available PostgreSQL 16 minor version before applying:
#   aws rds describe-db-engine-versions \
#     --engine postgres --engine-version 16 \
#     --query 'DBEngineVersions[*].EngineVersion'

resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "postgres"
  engine_version = "16.3"

  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  # Config
  parameter_group_name       = aws_db_parameter_group.postgres16.name
  auto_minor_version_upgrade = true

  # Backups
  # Windows expressed in UTC. 20:30–21:30 UTC = 02:00–03:00 IST (well after ETL).
  backup_retention_period = var.backup_retention_days
  backup_window           = "20:30-21:30"
  maintenance_window      = "sun:21:00-sun:22:00"
  copy_tags_to_snapshot   = true

  # Observability
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  # Safety
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project}-db-final-snapshot"

  tags = { Name = "${var.project}-db" }

  lifecycle {
    prevent_destroy = true
    # Ignore engine_version drift caused by auto minor version upgrades
    ignore_changes = [engine_version]
  }
}

# ── Enhanced Monitoring IAM Role ──────────────────────────────────────────────

resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
