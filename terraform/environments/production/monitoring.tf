# ── SNS Alert Topic ───────────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
  tags = { Name = "${var.project}-alerts" }
}

# Email subscription — AWS will send a confirmation email.
# The subscription becomes active only after the link in that email is clicked.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── RDS CloudWatch Alarms ─────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-rds-high-cpu"
  alarm_description   = "RDS CPU utilisation above 80% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = aws_db_instance.main.id }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.project}-rds-low-storage"
  alarm_description   = "RDS free storage below 5 GB — review data growth or increase max_allocated_storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120 # 5 GB in bytes
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = aws_db_instance.main.id }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project}-rds-high-connections"
  alarm_description   = "RDS connections above 80 — consider RDS Proxy if this persists"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  threshold           = 80
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = aws_db_instance.main.id }
}

resource "aws_cloudwatch_metric_alarm" "rds_memory" {
  alarm_name          = "${var.project}-rds-low-memory"
  alarm_description   = "RDS freeable memory below 256 MB — consider upgrading to db.t3.medium"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  threshold           = 268435456 # 256 MB in bytes
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = aws_db_instance.main.id }
}

resource "aws_cloudwatch_metric_alarm" "rds_write_latency" {
  alarm_name          = "${var.project}-rds-high-write-latency"
  alarm_description   = "RDS write latency above 500ms — ETL inserts may be slow"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 60
  statistic           = "Average"
  threshold           = 0.5
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = { DBInstanceIdentifier = aws_db_instance.main.id }
}
