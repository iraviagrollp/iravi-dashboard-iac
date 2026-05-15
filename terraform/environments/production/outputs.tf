output "vpc_id" {
  description = "VPC ID — needed when adding future resources"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs — attach Lambda functions and ElastiCache to these"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "sg_lambda_id" {
  description = "Attach this security group to every Lambda function in this project"
  value       = aws_security_group.lambda.id
}

output "sg_rds_id" {
  value = aws_security_group.rds.id
}

output "sg_elasticache_id" {
  description = "Attach this security group to the ElastiCache cluster (provisioned in a later step)"
  value       = aws_security_group.elasticache.id
}

output "rds_endpoint" {
  description = "RDS hostname — already written to Secrets Manager, Lambda reads from there"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "db_secret_arn" {
  description = "Pass this ARN to each Lambda's IAM policy so it can read DB credentials"
  value       = aws_secretsmanager_secret.db.arn
}

output "sns_alerts_arn" {
  description = "Pass this ARN to ETL and Redis Updater Lambda for failure notifications"
  value       = aws_sns_topic.alerts.arn
}
