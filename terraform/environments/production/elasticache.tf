# ── ElastiCache Redis ─────────────────────────────────────────────────────────
# Single-node Redis 7 cluster in private subnets.
# Security group (sg_elasticache) and subnet group reference existing private
# subnets — both already defined in security_groups.tf and vpc.tf respectively.
# REDIS_HOST output is consumed by lambda_redis_updater.tf and lambda_api.tf.

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${var.project}-cache-subnet-group" }
}

resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${var.project}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.elasticache.id]
  tags                 = { Name = "${var.project}-redis" }
}
