### Not fully tested (2022.05.04)
/*  Naming rule
    SubnetGroup: sg_[engine]_[identifier]_[service name]_[purpose]_[env]_[region] ex) sg_aurora-mysql_main_dks_svc_prod_kr
    OptionGroup: og-[engine]-[identifier]-[service name]-[purpose]-[env]-[region] ex) og-aurora-mysql_main-dks-svc-prod-kr (* underline not allowed)
    ParameterGroup: pg-[engine]_[identifier]-[service name]-[purpose]-[env]-[region] ex) pg_cluster/db-aurora-mysql57_dks_svc_prod_kr (* underline not allowed)
    RDS DB: [engine]-[identifier]-[service name]-[purpose]-[env]-[region] ex) aurora-mysql-main-dks-svc-prod-kr (* underline not allowed)
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
    suffixes = ["${local.svc_name}_${local.purpose}_${local.env}_${local.region_name_alias}", 
                "${local.svc_name}-${local.purpose}-${local.env}-${local.region_name_alias}" ]
}

data "aws_db_snapshot" "selected" {
    for_each = var.snapshot_identifier != null ? toset([var.snapshot_identifier]) : []
    db_snapshot_identifier = var.snapshot_identifier
}

resource "aws_db_subnet_group" "default" {
    # Naming rule: sg_[engine]_[cluster_id]_[aws server]_[service name]_[purpose]_[env]_[region] ex) sg_aurora-mysql_main_dks_svc_prod_kr
    name = "sg_${var.engine}_${var.identifier}_${local.suffixes[0]}"
    description = "RDS Subnet group for ${var.identifier} database"
    subnet_ids = var.subnet_ids
    tags = {
        Name = "sg_${var.engine}_${var.identifier}_${local.suffixes[0]}"
    }
}

resource "aws_db_option_group" "main" {
    for_each = try(var.option_group_name, null) != null ? [] : toset(["default"])
    name = "og-${var.engine}-${join("", slice(split(".", var.engine_version),0,2))}-${var.identifier}-${local.suffixes[1]}"
    engine_name = var.engine
    major_engine_version = (var.engine == "mysql" || var.engine == "mariadb") ? join(".", slice(split(".", var.engine_version), 0, 2)) : join(".", slice(split(".", var.engine_version), 0, 1))
    option_group_description = "RDS option group for ${var.identifier} instance"
    dynamic "option" {
        for_each = var.option_group
        content {
            option_name = option.key
            port = try(option.value.port, null)
            version = try(option.value.version, null)
            db_security_group_memberships = try(option.value.db_security_group_memberships, null)
            vpc_security_group_memberships = try(option.value.vpc_security_group_memberships, null)
            dynamic "option_settings" {
                for_each = try(option.value.option_settings, [])
                content {
                    name = option_settings.value.name
                    value = option_settings.value.value
                }
            }
        }
    }
    tags = {
        Name = "og_${var.engine}-${join("", slice(split(".", var.engine_version),0,2))}_${var.identifier}_${local.suffixes[0]}"
    }
}

resource "aws_db_parameter_group" "main" {
    for_each = try(var.parameter_group_name, null) != null ? [] : toset(["default"])
    # Naming rule: pg_db-[name]_[service name]_[purpose]_[env]_[region] ex) pg_db-aurora-mysql57_dks_svc_prod_kr
    name  = "pg-db-${replace(var.parameter_group.family, ".", "")}-${var.identifier}-${local.suffixes[1]}"
    description = "RDS parameter group for ${var.identifier} instance"
    family = var.parameter_group.family
    dynamic "parameter" {
        for_each = try(var.parameter_group.parameters, [])
        content {
            name = parameter.value.key
            value = parameter.value.value
            apply_method = try(parameter.value.apply_method, "immediate")
        }
    }
    tags = {
        Name = "pg_db_${var.parameter_group.family}-${var.identifier}_${local.suffixes[0]}"

    }
    lifecycle {
        ignore_changes = [parameter]
    }
}

resource "aws_db_instance" "main" {
    # DB instance
    engine = var.engine
    engine_version = var.engine_version
    instance_class = var.instance_class
    license_model = var.license_model
    
    identifier = "${var.engine}-${var.identifier}-${local.suffixes[1]}"
    #identifier = var.identifier
    identifier_prefix = var.identifier != null ? var.identifier_prefix : null
    snapshot_identifier = var.snapshot_identifier # Create RDS from snapshot
    
    db_name = var.db_name
    domain = var.domain
    domain_iam_role_name = var.domain_iam_role_name
    username = var.snapshot_identifier == null && var.replicate_source_db == null ? var.username : null
    password = var.snapshot_identifier == null && var.replicate_source_db == null ? var.password : null
    
    # Network
    multi_az = var.multi_az
    availability_zone = var.multi_az ? null : var.availability_zone
    db_subnet_group_name = aws_db_subnet_group.default.name
    port = var.port

    # Options/Parameters
    option_group_name = ( var.snapshot_identifier != null ? data.aws_db_snapshot.selected[var.snapshot_identifier].option_group_name :  
                            var.option_group_name != null ? var.option_group_name : aws_db_option_group.main["default"].id
                        )
    parameter_group_name = var.parameter_group_name != null ? var.parameter_group_name : aws_db_parameter_group.main["default"].id
    
    # Storage
    allocated_storage = var.snapshot_identifier == null && var.replicate_source_db == null ? var.allocated_storage : null 
    max_allocated_storage = var.max_allocated_storage
    storage_type = var.storage_type
    iops = var.iops
    
    # Replication
    replica_mode = var.replica_mode
    replicate_source_db = var.replicate_source_db
    
    # maintenance
    maintenance_window = var.maintenance_window
    allow_major_version_upgrade = var.allow_major_version_upgrade
    auto_minor_version_upgrade = var.auto_minor_version_upgrade
    apply_immediately = var.apply_immediately
    
    # Backup/restore
    backup_retention_period = var.backup_retention_period
    backup_window = var.backup_window
    copy_tags_to_snapshot = var.copy_tags_to_snapshot
    delete_automated_backups = var.delete_automated_backups
    skip_final_snapshot = var.final_snapshot_identifier == null ? true : false
    final_snapshot_identifier = var.final_snapshot_identifier
    dynamic "restore_to_point_in_time" {
        for_each = try(var.restore_to_point_in_time, null) != null ? [var.restore_to_point_in_time] : []
        content {
            restore_time = try(restore_to_point_in_time.value.restore_time, null)
            use_latest_restorable_time = try(restore_to_point_in_time.value.use_latest_restorable_time, null)
            source_db_instance_identifier = try(restore_to_point_in_time.value.source_db_instance_identifier, null)
            source_db_instance_automated_backups_arn = try(restore_to_point_in_time.value.source_db_instance_automated_backups_arn, null)
            source_dbi_resource_id = try(restore_to_point_in_time.value.source_dbi_resource_id, null)
        }
    }
    dynamic "s3_import" {
        for_each = try(var.s3_import, null) != null ? [var.s3_import] : []
        content {
            source_engine = s3_import.value.source_engine
            source_engine_version = s3_import.value.source_engine_version
            bucket_name = s3_import.value.bucket_name
            bucket_prefix = try(s3_import.value.bucket_prefix, null)
            ingestion_role = s3_import.value.bucket_prefix
        }
    }
    
    # Logging
    enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
    
    # Monitoring
    monitoring_interval = var.monitoring_interval
    performance_insights_enabled = var.performance_insights_enabled
    performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
    
    # Security
    publicly_accessible = var.publicly_accessible
    vpc_security_group_ids = var.security_group_ids
    ca_cert_identifier = var.ca_cert_identifier
    iam_database_authentication_enabled = var.iam_database_authentication_enabled
    storage_encrypted = var.storage_encrypted
    kms_key_id = var.kms_key_id
    performance_insights_kms_key_id = var.performance_insights_kms_key_id
    
    # Other options
    character_set_name = var.character_set_name
    deletion_protection = var.deletion_protection
    nchar_character_set_name = var.nchar_character_set_name
    timezone = var.timezone
    customer_owned_ip_enabled = var.customer_owned_ip_enabled
    
    tags = {
        Name = "${var.engine}_${var.identifier}_${local.suffixes[0]}"
    }
    
    depends_on = [aws_db_subnet_group.default, aws_db_option_group.main, aws_db_parameter_group.main, data.aws_db_snapshot.selected]
}

# DB Integration role mapping
resource "aws_db_instance_role_association" "main" {
    for_each = var.db_instance_role
    db_instance_identifier = aws_db_instance.main.id
    feature_name = each.key
    role_arn = each.value
}