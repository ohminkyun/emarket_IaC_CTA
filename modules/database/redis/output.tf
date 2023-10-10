output "replication_group_arn" {
    description = "Redis replication group arn"
    value = aws_elasticache_replication_group.redis.arn
}

output "replication_group_id" {
    description = "Redis replication group ID"
    value = aws_elasticache_replication_group.redis.id
}

output "replication_group_port" {
    description = "Redis service port"
    value = var.port
}

output "redis_node_ids" {
    description = "Redis cluster nodes IDs"
    value = aws_elasticache_replication_group.redis.member_clusters
}

output "primary_endpoint" {
    description = "Redis primary endpoint"
    value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "read_endpoint" {
    description = "Redis read endpoint"
    value = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "engine_version_actual" {
    description = "Redis engine version"
    value = aws_elasticache_replication_group.redis.engine_version_actual
}