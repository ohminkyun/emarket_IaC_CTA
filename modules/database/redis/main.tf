/*  Naming rule
    SubnetGroup: sg_[name]_[service name]_[purpose]_[stage]_[region] ex) sg_redis_dks_svc_prod_kr
    ParameterGroup: pg_[name]_[service name]_[purpose]_[env]_[region] ex) pg_redis6x_dks_svc_prod_kr
    Redis: redis_[name]-[service name]-[purpose]-[env]-[region] ex) redis-session-dks-svc-prod-kr
          * underline not allowed
*/
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}

locals {
    svc_name = lower(var.svc_name)
    purpose = lower(var.purpose)
    env = lower(var.env)
    region_name_alias = lower(var.region_name_alias)
    suffixes =  ["${local.svc_name}_${local.purpose}_${local.env}_${local.region_name_alias}", 
                "${local.svc_name}-${local.purpose}-${local.env}-${local.region_name_alias}"]
}   

resource "aws_elasticache_parameter_group" "default" {
    name = "pg-${replace(var.parameter_group, ".", "")}-${local.suffixes[1]}"
    description = "pg_${replace(var.parameter_group, ".", "")}_${local.suffixes[1]}"
    family = var.parameter_group
    dynamic "parameter" {
        for_each = var.elasticache_parameters
        content {
            name = parameter.key
            value = parameter.value
        }
    }
    tags = {
        Name: "pg_${var.parameter_group}_${local.suffixes[0]}"
    }
    lifecycle {
        ignore_changes = [parameter]
    }
}

resource "aws_elasticache_subnet_group" "redis" {
    description = "ElastiCache Subnet group"
    # Naming rule: sg_[aws server]_[service name]_[purpose]_[env]_[region] ex) sg_redis_dks_prod_kr
    name = "sg-redis-${local.suffixes[1]}"
    subnet_ids = var.subnet_ids
    tags = {
        Name = "sg_redis_${local.suffixes[0]}"
    }
}

# Redis Repl-Group (Non-cluster)
resource "aws_elasticache_replication_group" "redis" {
    availability_zones = var.az_names
    # Naming rule redis_[name]-[service name]-[purpose]-[env]-[region] ex) redis-session-dks-svc-prod-kr
    replication_group_id = "redis-${var.replication_group_id}-${local.suffixes[1]}"

    description = "Redis replication group"
    node_type = var.node_type
    num_cache_clusters = var.num_cache_cluster
    engine_version = var.engine_version
    #cluster mode, non-cluster mode ex) default.redis6.x or default.redis6.x.cluster.on (cluster mode)
    parameter_group_name = aws_elasticache_parameter_group.default.name
    port = var.port

    # Additional options
    apply_immediately = var.apply_immediately
    auto_minor_version_upgrade = var.auto_minor_version_upgrade
    automatic_failover_enabled = var.num_cache_cluster > 1 ? true : false
    multi_az_enabled = var.num_cache_cluster > 1 ? true : false
    snapshot_retention_limit = var.snapshot_retention_limit

    maintenance_window = var.maintanence_window
    notification_topic_arn = var.notification_topic_arn
    security_group_ids = var.security_group_ids
    subnet_group_name = aws_elasticache_subnet_group.redis.name

    tags = merge(
        var.tags, 
        {
            # Naming rule redis_[name]-[service name]-[purpose]-[env]-[region] ex) redis-session-dks-svc-prod-kr
            Name = "redis_${var.replication_group_id}_${local.suffixes[0]}"
        }
    )
}