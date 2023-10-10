# AWS rds Module

AWS의 general RDS 를 생성하는 모듈입니다. 

AWS RDS에 대한 자세한 내용은 아래의 AWS 문서를 참고하도록 합니다.

> ✔ [`RDS`](https://docs.aws.amazon.com/ko_kr/AmazonRDS/latest/UserGuide/Welcome.html) - Amazon Relational Database Service(Amazon RDS)는 AWS 클라우드에서 관계형 데이터베이스를 더 쉽게 설치, 운영 및 확장할 수 있는 웹 서비스입니다. 이 서비스는 산업 표준 관계형 데이터베이스를 위한 경제적이고 크기 조절이 가능한 용량을 제공하고 공통 데이터베이스 관리 작업을 관리합니다.



## 인프라 사전 준비사항

다음의 인프라가 사전에 설치되어 있어야만, 본 모듈을 사용하여 자원을 생성할 수 있습니다.

|    AWS 인프라    |                          간단 설명                           | Required |     사용 가능 모듈     |
| :--------------: | :----------------------------------------------------------: | :------: | :--------------------: |
|       VPC        | [사용자 정의 가상 네트워크](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/what-is-amazon-vpc.html) |  `yes`   |      network/vpc       |
|      Subnet      | [VPC의 IP주소범위](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/configure-subnets.html) |  `yes`   |      network/vpc       |
|   Route table    | [네트워크 트래픽 전송규칙](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/VPC_Route_Tables.html) |  `yes`   |      network/vpc       |
| Internet Gateway | [인터넷 연결 리소스](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/VPC_Internet_Gateway.html) |   `no`   |      network/vpc       |
|   NAT Gateway    | [Private 서브넷의 인터넷 연결 리소스](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/vpc-nat-gateway.html) |   `no`   |      network/vpc       |
|   Network ACL    | [네트워크 방화벽](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/vpc-network-acls.html) |   `no`   |      network/vpc       |
| Security Groups  | [Host 방화벽을 통한 접근제어](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/VPC_SecurityGroups.html) |  `yes`   | security/securitygroup |



## 사용예시

아래의 코드를 사용하여 general RDS를 생성할 수 있습니다. (※ 아래의 예시 코드에서는 이해를 돕기 위해 변수대신 값을 사용하였으며, 대부분 변수를 사용합니다.)

```yaml
module "rds" {
    source = "../../../modules/database/rds"
    svc_name = "km"
    purpose = "svc"
    env = "prd"
    region_name_alias = "kr"
    engine = "mysql"
    engine_version = "5.7"
    auto_minor_version_upgrade = true
    instance_class = "db.t3.micro"
    identifier = "main"
    multi_az = false
    subnet_ids = ["subnet-******", "subnet-******"]  
    port = 5306   
    allocated_storage = 10
    max_allocated_storage = 15
    storage_type = "gp2"
    apply_immediately = true
    storage_encrypted = true
    security_group_ids = ["sg-******"]
    parameter_group = { family = "mysql5.7" }
    tags = {
        RES_Class_0 = "SERVICE"
        RES_Class_1 = "DB"
        RES_Class_2 = "KR"
        SEC_PII = "N"
    }
}
```

- aurora cluster name등, resource들은 아래의 naming rule을 따라 생성됩니다. <br>resource naming, tagging시 svc_name, purpose, env, region_name_alias와 같은 variable들이 suffix로 사용됩니다.

  > 1. SubnetGroup Name: sg\_[engine]\_[identifier]\_[service name]\_[purpose]\_[env]\_[region] ex) sg_aurora-mysql_main_km_svc_prd_kr
  > 2. OptionGroup Name: og-[engine]-[identifier]-[service name]-[purpose]-[env]-[region] ex) og-aurora-mysql_main-km-svc-prd-kr (*underline not allowed*)
  > 3. ParameterGroup Name: pg-[engine]-[identifier]-[service name]-[purpose]-[env]-[region] ex) pg_cluster/db-aurora-mysql57_km_svc_prd_kr (*underline not allowed*)
  > 4. RDS DB Name: [engine]-[identifier]-[service name]-[purpose]-[env]-[region] ex) aurora-mysql-main-km-svc-prd-kr (*underline not allowed*)

- multi_az variable의 여부에 따라 이중화 여부가 선택됩니다.

- allocated_storage, max_allocated_storage variable을 사용하여 storage auto-scaling을 사용할 수 있으며, max_allocated_storage가 0인 경우, storage auto scaling feature를 disable합니다.



## Requirements

| Name      | Version |
| :-------- | :-----: |
| terraform | >= 0.12 |



## Providers

| Name | Version |
| :--- | :-----: |
| aws  | >~ 4.0  |



## Resources

| Name                                                         |   Type   |
| :----------------------------------------------------------- | :------: |
| [aws_db_subnet_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_db_option_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_option_group) | resource |
| [aws_db_parameter_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_instance_role_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance_role_association) | resource |



## Inputs

| Name                                                         | Description                                                  |      Type      |        Default        | Required |
| :----------------------------------------------------------- | :----------------------------------------------------------- | :------------: | :-------------------: | :------: |
| svc_name                                                     | VPC의 사용 용도                 |    `string`    |                       |  `yes`   |
| purpose                                                      | VPC의 용도를 나타낼 수 있는 서비스 명 (ex, svc / mgmt)       |    `string`    |                       |  `yes`   |
| env                                                          | 시스템 구성 환경 (ex, dev / stg / prod)                      |    `string`    |                       |  `yes`   |
| region_name_alias                                            | 서비스 AWS Region alias (ex, ap-northeast-2 → kr)            |    `string`    |                       |  `yes`   |
| engine                                                       | RDS Engine type설정 (ex, `aurora-mysql`)                     |    `string`    |                       |  `yes`   |
| engine_version                                               | RDS Engine version                                           |    `string`    |                       |  `yes`   |
| instance_class                                               | RDS instance class                                           |    `string`    |                       |  `yes`   |
| identifier                                                   | RDS DB instance ID 설정                                      |    `string`    |                       |  `yes`   |
| identifier_prefix                                            | RDS DB instance ID prefix (identifier와 exclusive)           |    `string`    |        `null`         |   `no`   |
| license_model                                                | License model information for this DB instance (`license-included`, `bring-your-own-license`, `general-public-license`) |    `string`    |        `null`         |   `no`   |
| multi_az                                                     | RDS DB availability zone 이중화 여부                         |     `bool`     |        `false`        |   `no`   |
| availability_zone                                            | RDS DB instance를 설치할 Availability zone (multi_az를 사용하는 경우 Not Applicable) |    `string`    |        `null`         |   `no`   |
| subnet_ids                                                   | VPC subnet IDs for RDS instance                              | `list(string)` |                       |  `yes`   |
| port                                                         | DB port number                                               |    `number`    |        `5306`         |  `yes`   |
| db_name                                                      | Database name (null인 경우, 자동 DB생성하지 않음)            |    `string`    |        `null`         |   `no`   |
| username                                                     | DB username                                                  |    `string`    |                       |  `yes`   |
| password                                                     | DB password                                                  |    `string`    |                       |  `yes`   |
| **option_group**                                             | RDS DB instance option group 생성 후 설정                    |   `map(any)`   |         `{}`          |   `no`   |
| **option_group**.port                                        | Port number when connecting to the Option                    |    `number`    |        `null`         |   `no`   |
| **option_group**.version                                     | The version of the option                                    |    `string`    |        `null`         |   `no`   |
| **option_group**.db_security_group_memberships               | DB Security Groups for which the option is enabled           | `list(string)` |         `[]`          |   `no`   |
| **option_group**.vpc_security_group_memberships              | VPC Security Groups for which the option is enabled          | `list(string)` |         `[]`          |   `no`   |
| **option_group**.*option_settings*                           | Option name, value 설정                                      | `list(object)` |         `[]`          |   `no`   |
| **option_group**.*option_settings*.<br>name                  | Option name                                                  |    `string`    |                       |  `yes`   |
| **option_group**.*option_settings*.<br>value                 | Option value                                                 |    `string`    |                       |  `yes`   |
| option_group_name                                            | 기 생성된 option group을 적용할 때 사용                      |    `string`    |        `null`         |   `no`   |
| **parameter_group**                                          | RDS instance parameter group                                 |     `any`      |                       |  `yes`   |
| **parameter_group**.family                                   | family of db instance parameter group (ex, `aurora-mysql5.7`) |    `string`    |                       |  `yes`   |
| **parameter_group**.*parameters*                             | DB instance parameter 항목을 정의                            | `list(object)` |         `[]`          |   `no`   |
| **parameter_group**.*parameters*.<br>name                    | DB instance parameter name                                   |    `string`    |                       |  `yes`   |
| **parameter_group**.*parameters*.<br>value                   | DB instance parameter value                                  |    `string`    |                       |  `yes`   |
| **parameter_group**.*parameters*.<br>apply_method            | apply method (`immediate`, `pending-reboot`)                 |    `string`    |      `immediate`      |   `no`   |
| parameter_group_name                                         | 기 생성된 parameter group을 적용할 때 사용                   |    `string`    |        `null`         |   `no`   |
| domain                                                       | ID of the Directory Service Active Directory domain to create the instance in |    `string`    |        `null`         |   `no`   |
| domain_iam_role_name                                         | IAM role to be used when making API calls to the Directory Service |    `string`    |        `null`         |   `no`   |
| allocated_storage                                            | RDS DB storage 용량 (replicate_source_db가 설정되면 무시되는 값) |    `number`    |                       |  `yes`   |
| max_allocated_storage                                        | upper limit to which Amazon RDS can automatically scale the storage of the DB instance (0은 auto scaling disable 시킴) |    `number`    |          `0`          |   `no`   |
| storage_type                                                 | RDS DB storage type (`general`, `gp2`, `io1`)                |    `string`    |        `null`         |   `no`   |
| iops                                                         | io1 storage type의 IOPS                                      |    `number`    |        `null`         |   `no`   |
| maintanence_window                                           | Preferred maintanence window (UTC이므로 시간설정에 주의한다) |    `string`    | `sat:15:00-sat:16:00` |   `no`   |
| allow_major_version_upgrade                                  | major version upgrade를 자동으로 실행할지 여부               |     `bool`     |        `false`        |   `no`   |
| auto_minor_version_upgrade                                   | minor version upgrade를 자동으로 실행할지 여부               |     `bool`     |        `false`        |   `no`   |
| apply_immediately                                            | 변경사항을 즉시 반영할지 여부 설정                           |     `bool`     |        `false`        |   `no`   |
| replicate_source_db                                          | DB를 replicate할 때, Replicate source database 정보 설정     |    `string`    |        `null`         |   `no`   |
| replica_mode                                                 | Specifies whether the replica is in either mounted or open-read-only mode (only supported by Oracle instance) |    `string`    |   `open-read-only`    |   `no`   |
| enabled_cloudwatch_logs_exports                              | cloudwatch log stream for audit, error, general, slowquery   | `list(string)` |         `[]`          |   `no`   |
| monitoring_interval                                          | cloudwatch의 RDS Enhanced 모니터링 주기 (0: disable enhanced monitoring) |    `number`    |          `0`          |   `no`   |
| monitoring_role_arn                                          | RDS Monitoring Role ARN (Enhanced monitoring 사용시 필요)    |    `string`    |        `null`         |   `no`   |
| performance_insights_enabled                                 | RDS performance insights를 사용할지 여부                     |     `bool`     |        `false`        |   `no`   |
| performance_insights_retention_period                        | Performance Insights data 보관주기 (days)                    |    `number`    |          `7`          |   `no`   |
| backup_retention_period                                      | Backup retention days (Backup retention 0 is disable automatic backup) |    `number`    |          `1`          |   `no`   |
| backup_window                                                | Preferred backup window (UTC이므로 시간설정에 주의한다)      |    `string`    |     `20:00-21:00`     |   `no`   |
| copy_tags_to_snapshot                                        | Copy all Instance tags to snapshots                          |     `bool`     |        `false`        |   `no`   |
| delete_automated_backups                                     | DB instance가 지워지면 바로 자동 백업본까지 모두 삭제할지 여부 |     `bool`     |        `false`        |   `no`   |
| final_snapshot_identifier                                    | The name of your final DB snapshot when this DB cluster is deleted |    `string`    |        `null`         |   `no`   |
| snapshot_identifier                                          | Snapshot을 통해서 RDS를 생성할 때 snapshot정보를 설정        |    `string`    |        `null`         |   `no`   |
| **restore_to_point_in_time**                                 | 시점 복구 설정                                               |     `any`      |        `null`         |   `no`   |
| **restore_to_point_in_time**.source_db_instance_identifier   | 복구할 RDS instance ID                                       |    `string`    |        `null`         |   `no`   |
| **restore_to_point_in_time**.source_db_instance_automated_backups_arn | 복구에 사용할 Automated backup본의 ARN                       |    `string`    |        `null`         |   `no`   |
| **restore_to_point_in_time**.source_dbi_resource_id          | 복구할 Source DB instance의 resource ID                      |    `string`    |        `null`         |   `no`   |
| **restore_to_point_in_time**.restore_time                    | 복구 시점 정의 (use_latest_restorable_time와 함께 사용불가, UTC format) |    `string`    |        `null`         |   `no`   |
| **restore_to_point_in_time**.use_latest_restorable_time      | 복구 가능한 시점까지 복구할지 여부선택                       |     `bool`     |        `false`        |   `no`   |
| **s3_import**                                                | S3로 부터 Xtrabackup을 통한 복구 설정                        |     `any`      |        `null`         |   `no`   |
| **s3_import**.source_engine                                  | RDS source engine 명 (as of Feb 2018 only 'mysql' supported) |    `string`    |                       |  `yes`   |
| **s3_import**.source_engine_version                          | RDS source engine version (as of Feb 2018 only 'mysql' supported) |    `string`    |                       |  `yes`   |
| **s3_import**.bucket_name                                    | Xtrabackup이 있는 S3 bucket 명                               |    `string`    |                       |  `yes`   |
| **s3_import**.bucket_prefix                                  | Xtrabackup이 있는 S3 bucket prefix                           |    `string`    |        `null`         |   `no`   |
| **s3_import**.ingestion_role                                 | IAM Role arn to restore data                                 |    `string`    |                       |  `yes`   |
| publicly_accessible                                          | Bool to control if instance is publicly accessible           |     `bool`     |        `false`        |   `no`   |
| security_group_ids                                           | RDS Security Group IDs                                       | `list(string)` |                       |  `yes`   |
| ca_cert_identifier                                           | RDS db instance CA certification ID                          |    `string`    |        `null`         |   `no`   |
| iam_database_authentication_enabled                          | DB인증을 IAM과 연동할지 여부                                 |     `bool`     |        `false`        |   `no`   |
| storage_encrypted                                            | DB storage를 encrypt할지 여부                                |     `bool`     |        `false`        |   `no`   |
| kms_key_id                                                   | DB storage를 encrypt할 때 사용할 kms key id                  |    `string`    |        `null`         |   `no`   |
| performance_insights_kms_key_id                              | performance insights data를 encryption할 때 사용할 kms key id |    `string`    |        `null`         |   `no`   |
| character_set_name                                           | oracle charset name 정의                                     |    `string`    |        `null`         |   `no`   |
| deletion_protection                                          | DB instance가 삭제되지 않도록 설정                           |     `bool`     |        `false`        |   `no`   |
| nchar_character_set_name                                     | oracle에서 사용할 char set name 정의                         |    `string`    |        `null`         |   `no`   |
| timezone                                                     | Microsoft SQL Server 에서 사용할 time zone 설정              |    `string`    |        `null`         |   `no`   |
| customer_owned_ip_enabled                                    | RDS outpost DB instance 사용 시, customer-owned IP address (CoIP)를 사용할 것인지 여부 |     `bool`     |        `false`        |   `no`   |
| db_instance_role                                             | (DB인스턴스에 role할당), AWS서비스와 통합된 DB Feature를 사용하기 위해 IAM 권한 매핑 | `map(string)`  |         `{}`          |   `no`   |
| tags                                                         | RDS additional resource tags (key, value)                    | `map(string)`  |         `{}`          |   `no`   |

### 참고

------

**option_group** - option_group  input variable은 아래와 같은 구조로 구성되어 있다. (실제 variable type은 any이나 아래와 같은 형식으로 사용되고 있음을 참고)

```yaml
# key => option_name #(Required) The Name of the Option (e.g., MEMCACHED)
type = map(object({
   port = number #(Optional) The Port number when connecting to the Option (e.g., 11211)
   version = string #(Optional) The version of the option (e.g., 13.1.0.0)
   db_security_group_memberships = list(string) #(Optional) A list of DB Security Groups
   vpc_security_group_memberships = list(string) #(Optional) A list of VPC Security Groups
   option_settings = list(object({
       name = string #(Optional) The Name of the setting
       value = string # (Optional) The Value of the setting
   }))
}))
```

**parameter_group** - parameter_group input variable은 아래와 같은 구조로 구성되어 있다. (실제 variable type은 any이나 아래와 같은 형식으로 사용되고 있음을 참고)

```yaml
type = object({
    family = string #(Required, Forces new resource) The family of the DB parameter group.(aurora-mysql5.7)
    parameters = list(object({ #(Optional)
        name = string #(Required) The name of the DB parameter
        value = string  #(Required) The value of the DB parameter
        apply_method = string #(Optional) "immediate" (default), or "pending-reboot"
    }))
})
```

**restore_to_point_in_time** - restore_to_point_in_time input variable은 아래와 같은 구조로 구성되어 있다. (실제 variable type은 any이나 아래와 같은 형식으로 사용되고 있음을 참고)

```yaml
type = object({
    restore_time = string #(Optional)
    use_latest_restorable_time = bool #(Optional) 
    source_db_instance_identifier = string #(Optional)
    source_db_instance_automated_backups_arn = string #(Optional)
    source_dbi_resource_id = string #(Optional)
})
```

**s3_import** - s3_import input variable은 아래와 같은 구조로 구성되어 있다. (실제 variable type은 any이나 아래와 같은 형식으로 사용되고 있음을 참고)

```yaml
type = object({
    source_engine = string #(Required, as of Feb 2018 only 'mysql' supported)
    source_engine_version = string #(Required, as of Feb 2018 only '5.6' supported)
    bucket_name = string #(Required) 
    bucket_prefix = string #(Optional) 
    ingestion_role = string #(Required) 
})
```



## Outputs

| Name               | Description                |
| :----------------- | :------------------------- |
| cluster_id         | RDS cluster ID             |
| cluster_arn        | RDS cluster ARN            |
| cluster_endpoint   | RDS cluster Endpoint       |
| cluster_port       | RDS cluster service port   |
| reader_endpoint    | RDS reader Endpoint        |
| instance_endpoints | RDS instance들의 Endpoints |
| instance_arns      | RDS instance들의 ARNs      |