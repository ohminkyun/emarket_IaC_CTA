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

### DB Engine ###
variable "engine" {
    description = "The database engine to use"
    type = string
    /* supported values: https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_CreateDBInstance.html */
}

variable "engine_version" {
    description = "The engine version to use. If auto_minor_version_upgrade is enabled, you can provide a prefix of the version such as 5.7 (for 5.7.10)"
    type = string
}

variable "instance_class" {
    description = "(Required) The instance type of the RDS instance"
    type = string
}

variable "identifier" {
    description = "The name of the RDS instance, if omitted, Terraform will assign a random, unique identifier"
    type = string
}

variable "identifier_prefix" {
    description = "Creates a unique identifier beginning with the specified prefix. Conflicts with identifier"
    type = string
    default = null
}

variable "license_model" {
    description = "(Optional, but required for some DB engines, i.e., Oracle SE1) License model information for this DB instance"
    type = string
    default = null
    /* Valid values: license-included | bring-your-own-license | general-public-license */
}

variable "multi_az" {
    description = "Specifies if the RDS instance is multi-AZ"
    type = bool
    default = false
}

variable "availability_zone" {
    description = "The AZ for the RDS instance multi_az를 사용하는 경우, not applicable"
    type = string
    default = null
}

variable "subnet_ids" {
    description = "RDS subnet IDs"
    type = list(string)
}

variable "port" {
    description = "he port on which the DB accepts connections"
    type = number
    default = null
}

# https://awscli.amazonaws.com/v2/documentation/api/latest/reference/rds/create-db-instance.html
variable "db_name" {
    description = "The name of the database to create when the DB instance is created, oracle은 대문자, null => DB가 생성되지 않음(oracle, SQL서버 예외)"
    type = string
    default = null
}

variable "username" {
    description = "Username for the master DB user"
    type = string
    default = null
}

variable "password" {
    description = "Password for the master DB user"
    type = string
    default = null
}

variable "option_group" {
    description = "DB option group"
    type = map(any)
    /* key => option_name #(Required) The Name of the Option (e.g., MEMCACHED)
    type = map(object({
       port = number #(Optional) The Port number when connecting to the Option (e.g., 11211)
       version = string #(Optional) The version of the option (e.g., 13.1.0.0)
       db_security_group_memberships = list(string) #(Optional) A list of DB Security Groups for which the option is enabled
       vpc_security_group_memberships = list(string) #(Optional) A list of VPC Security Groups for which the option is enabled
       option_settings = list(object({
           name = string #(Optional) The Name of the setting
           value = string # (Optional) The Value of the setting
       }))
    }))
    */
    default = {}
}

variable "option_group_name" {
    description = "option group name for rds"
    type = string
    default = null
}

variable "parameter_group" {
    description = "Name of the DB parameter group to associate"
    type = any
    /*
    type = object(
        family = string #(Required, Forces new resource) The family of the DB parameter group.
        parameters = list(object({ #(Optional)
            name = string #(Required) The name of the DB parameter
            value = string  #(Required) The value of the DB parameter
            apply_method = string #(Optional) "immediate" (default), or "pending-reboot"
        }))
    )*/
    default = null
}

variable "parameter_group_name" {
    description = "parameter group name for RDS"
    type = string
    default = null
}

variable "domain" {
    description = "The ID of the Directory Service Active Directory domain to create the instance in"
    type = string
    default = null
}

variable "domain_iam_role_name" {
    description = "(Optional, but required if domain is provided) The name of the IAM role to be used when making API calls to the Directory Service."
    type = string
    default = null
}

### Storage ###
variable "allocated_storage" {
    description = "The allocated storage in gibibytes If replicate_source_db is set, the value is ignored during the creation of the instance"
    type = number
    default = 0
}

variable "max_allocated_storage" {
    description = "When configured, the upper limit to which Amazon RDS can automatically scale the storage of the DB instance (0 means diable storage autoscaling)"
    type = number # must be greater than allocated_storage
    default = 0
}

variable "storage_type" {
    description = "One of standard(magnetic),gp2(general purpose SSD), or io1(provisioned IOPS SSD) (The default is io1 if iops is specified)"
    type = string
    default = "gp2"
}

variable "iops" {
    description = "The amount of provisioned IOPS. Setting this implies a storage_type of io1"
    type = number
    default = 0
}

### Maintenence ###
variable "maintenance_window" {
    description = "Preferred maintanence window"
    type = string
    default = "sat:15:00-sat:16:00" # sun 00:00 ~ 01:00 KST
}

variable "allow_major_version_upgrade" {
    description = "Indicates that major version upgrades are allowed Changing this parameter does not result in an outage and the change is asynchronously applied as soon as possible"
    type = bool
    default = false
}

variable "auto_minor_version_upgrade" {
    description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window"
    type = bool
    default = false
}

variable "apply_immediately" {
    description = "Specifies whether any database modifications are applied immediately or during the next maintenance window"
    type = bool
    default = false
}

### Replication ###
variable "replicate_source_db" {
    description = "Specifies that this resource is a Replicate database"
    type = string
    default = null 
    /* DB_ID: same region source db, DB_ARN: other region source */
}

variable "replica_mode" {
    description = "Specifies whether the replica is in either mounted or open-read-only mode (only supported by Oracle instance)"
    type = string
    default = null
}

### logging ###
variable "enabled_cloudwatch_logs_exports" {
    description = "Set of log types to enable for exporting to CloudWatch logs. If omitted, no logs will be exported"
    type = list(string)
    default = []
    /* Valid values(depending on engine). 
       MySQL and MariaDB: audit,error,general,slowquery
       PostgreSQL: postgresql,upgrade
       MSSQL: agent,error
       Oracle: alert,audit,listener,trace */
}

### Monitoring ###
variable "monitoring_interval" {
    description = "he interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance"
    type = number
    default = 0 # 0 means disable collecting Enhanced Monitoring metrics
}

variable "monitoring_role_arn" {
    description = "The ARN for the IAM role that permits RDS to send enhanced monitoring metrics to CloudWatch Logs"
    type = string
    default = null
}

variable "performance_insights_enabled" {
    description = "Specifies whether Performance Insights are enabled"
    type = bool
    default = false
}

variable "performance_insights_retention_period" {
    description = "The amount of time in days to retain Performance Insights data"
    type = number
    default = 7 #7 days
}

### Backup/Restore ###
variable "backup_retention_period" {
    description = "The days to retain backups for. Must be between 0 and 35. Must be greater than 0 if the database is used as a source for a Read Replica"
    type = number
    default = 0
}

variable "backup_window" {
    description = "Preferred backup window"
    type = string
    #backup is controlled by AWS Backup
    default = "20:00-21:00" # 05:00 ~ 06:00 KST
}

variable "copy_tags_to_snapshot" {
    description = "Copy all Instance tags to snapshots"
    type = bool
    default = false
}

variable "delete_automated_backups" {
    description = "Specifies whether to remove automated backups immediately after the DB instance is deleted"
    type = bool
    default = true
}

variable "final_snapshot_identifier" {
    description = "The name of your final DB snapshot when this DB instance is deleted. Must be provided if skip_final_snapshot is set to false"
    type = string
    default = null
}

variable "snapshot_identifier" {
    description = "Specifies whether or not to create this database from a snapshot"
    type = string
    default = null
}

variable "restore_to_point_in_time" {
    description = "(Optional, Forces new resource) A configuration block for restoring a DB instance to an arbitrary point in time"
    type = any
    /* type = object({
        # restore_time, use_latest_restorable_time 중 택 1
        restore_time = string #(Optional) The date and time to restore from, use_latest_restorable_time와 함께 사용불가, UTC format
        use_latest_restorable_time = bool # (Optional) A boolean value that indicates whether the DB instance is restored from the latest backup time(default: false)
        # source_db_instance_identifier, source_db_instance_automated_backups_arn, source_dbi_resource_id 중 택 1개 이상
        source_db_instance_identifier = string # (Optional) The identifier of the source DB instance from which to restore
        source_db_instance_automated_backups_arn = string # (Optional)The ARN of the automated backup from which to restore
        source_dbi_resource_id = string #(Optional) The resource ID of the source DB instance from which to restore
    })*/
    default = null
}

variable "s3_import" {
    description = "Restore from a Percona Xtrabackup in S3"
    type = any
    /* type = object({
        source_engine = string #(Required, as of Feb 2018 only 'mysql' supported) Source engine for the backup
        source_engine_version = string #(Required, as of Feb 2018 only '5.6' supported) Version of the source engine used to make the backup
        bucket_name = string #(Required) The bucket name where your backup is stored
        bucket_prefix = string #(Optional) Can be blank, but is the path to your backup
        ingestion_role = string #(Required) Role applied to load the data
    })*/
    default = null
}

### Security ###
variable "publicly_accessible" {
    description = "Bool to control if instance is publicly accessible"
    type = bool
    default = false
}

variable "security_group_ids" {
    description = "List of VPC security groups to associate"
    type = list(string)
}

variable "ca_cert_identifier" {
    description = "The identifier of the CA certificate for the DB instance"
    type = string
    default = null
}

variable "iam_database_authentication_enabled" {
    description = "Specifies whether or mappings of AWS Identity and Access Management (IAM) accounts to database accounts is enabled"
    type = bool
    default = false
}

variable "storage_encrypted" {
    description = "Specifies whether the DB instance is encrypted"
    type = bool
    default = false
}

variable "kms_key_id" {
    description = "The ARN for the KMS encryption key"
    type = string
    default = null
}

variable "performance_insights_kms_key_id" {
    description = "The ARN for the KMS key to encrypt Performance Insights data"
    type = string
    default = null
}

### Other options ###
variable "character_set_name" {
    description = "he character set name to use for DB encoding in Oracle and Microsoft SQL instances (collation) This can't be changed"
    type = string
    default = null
}

variable "deletion_protection" {
    description = "If the DB instance should have deletion protection enabled. The database can't be deleted when this value is set to true"
    type = bool
    default = false
}

variable "nchar_character_set_name" {
    description = "(Optional, Forces new resource) The national character set is used in the NCHAR, NVARCHAR2, and NCLOB data types for Oracle instances. This can't be changed"
    type = string
    default = null
}

variable "timezone" {
    description = "Time zone of the DB instance. timezone is currently only supported by Microsoft SQL Server"
    type = string
    default = null
}

variable "customer_owned_ip_enabled" {
    description = "Indicates whether to enable a customer-owned IP address (CoIP) for an RDS on Outposts DB instance"
    type = bool
    default = false
}

variable "db_instance_role" {
    description = "Manages an RDS DB Instance association with an IAM Role (DB인스턴스에 role할당), AWS서비스와 통합된 DB Feature를 사용하기 위해 IAM 권한 매핑"
    type = map(string)
    default = {}
    /* values: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/oracle-s3-integration.html */
}

variable "tags" {
    description = "A map of tags to assign to the resource"
    type = map(string)
    default = {}
}