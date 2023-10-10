variable "svc_name" {
    description = "Service name"
    type = string
}

variable "purpose" {
    description = "VPC purpose"
    type = string
}

variable "env" {
    description = "Stage (dev, stg, prod etc)"
    type = string
}

variable "region_name_alias" {
    description = "AWS VPC region name alias like KR"
    type = string
}

variable "az_names" {
    description = "AWS subnet region name list"
    type = list(string)
}

variable "replication_group_id" {
    description = "ElastiCache replication group name"
    type = string
    # Naming rule redis_[purpose]_[service name]_[env]_[region] ex) redis_sess_dks_prod_kr
}

variable "subnet_ids" {
    description = "Redis service subnet IDs"
    type = list(string)
}

variable "security_group_ids" {
    description = "Redis service security group IDs"
    type = list(string)
}

variable "parameter_group" {
    description = "Redis parameter group"
    type = string
}

variable "node_type" {
    description = "redis node instance type"
    type = string
}

variable "num_cache_cluster" {
    description = "non-cluster mode: replication group member no, cluster-mode: cluster sharding no"
    type = number
    default = 1
}

variable "engine_version" {
    description = "Redis engine version"
    type = string
}

variable "port" {
    description = "Port no"
    type = number
    default = 8379
}

variable "apply_immediately" {
    description = "Apply configurations immediately"
    type = bool
    default = true
}

variable "auto_minor_version_upgrade" {
    description = "minor upgrade automatically"
    type = bool
    default = false
}

variable "maintanence_window" {
    description = "Preferred maintanence window"
    type = string
    default = "sat:15:00-sat:16:00" # sun 00:00 ~ 01:00 KST
}

variable "notification_topic_arn" {
    description = "Event notification SNS topic ARN"
    type = string
    default = null
}

variable "tags" {
    description = "Additional tags"
    type = map(string)
    default = {}
}

variable "elasticache_parameters" {
    description = "A list of ElastiCache parameters to apply"
    type = map(any)
    default = {}
}

variable "snapshot_retention_limit" {
    description = "Number of days for which ElastiCache will retain automatic cache cluster snapshots"
    type = number
    default = 0
}