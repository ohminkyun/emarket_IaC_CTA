# AWS redis Module

AWS에서 ElastiCache 중 Redis를 생성하는 모듈이며, Redis Replication 구성(HA)을 제공합니다. (<font color=red>redis clustering 아님</font>)

ElastiCache Redis에 대한 자세한 내용은 아래의 AWS 문서를 참고하기 바랍니다.

> ✔ [`ElastiCache`](https://aws.amazon.com/ko/elasticache/) - Amazon ElastiCache는 유연한 실시간 사용 사례를 지원하는 완전관리형 인 메모리 캐싱 서비스입니다. 
> [캐싱](https://aws.amazon.com/caching/)에 ElastiCache를 사용하면 애플리케이션 및 데이터베이스 성능을 가속화할 수 있으며, 세션 스토어, 게임 리더보드, 스트리밍 및 분석과 같이 내구성이 필요하지 않는 사용 사례에서는 기본 데이터 스토어로 사용할 수 있습니다. ElastiCache는 Redis 및 Memcached와 호환 가능합니다.



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

아래의 코드를 사용하여 ElastiCache Redis를 생성할 수 있습니다. (※ 아래의 예시 코드에서는 이해를 돕기 위해 변수대신 값을 사용하였으며, 대부분 변수를 사용합니다.)

```yaml
module "redis" {
    source = "../../../modules/database/redis"
    svc_name = "km"
    purpose = "svc"
    env = "prd"
    region_name_alias = "kr"
    az_names = ["ap-northeast-2a", "ap-northeast-2c"]
    replication_group_id = "session"
    node_type = "cache.t3.micro"
    num_cache_cluster = 2
    engine_version = "6.x"
    port = 8379
    parameter_group = "redis6.x"
    subnet_ids = ["subnet-******", "subnet-******"]
    security_group_ids = ["sg-******"]
    tags = {
        RES_Class_0 = "SERVICE"
        RES_Class_1 = "Cache"
        RES_Class_2 = "KR"
        SEC_PII = "N"
    }
}
```

- Elasticache name등, resource들은 아래의 naming rule을 따라 생성됩니다. <br>resource naming, tagging시 svc_name, purpose, env, region_name_alias와 같은 variable들이 suffix로 사용됩니다.   

  > 1. SubnetGroup Name: sg\_[name]\_[svc_name]\_[purpose]\_[env]\_[region] ex) sg_redis_dks_svc_prd_kr
  > 2. ParameterGroup Name: pg\_[name]\_[svc_name]\_[purpose]\_[env]\_[region] ex) pg_redis6x_dks_svc_prd_kr
  > 3. Redis Name: redis-[name]-[svc_name]-[purpose]-[env]-[region] ex) redis-session-dks-svc-prd-kr (*underline not allowed*)

- az_names의 갯수만큼 cluster instance를 생성하게 됩니다. (Replication group을 생성하여 HA를 제공하며, Redis clustering을 제공하는 것이 아님에 주의)

- az_names의 갯수보다 num_cache_cluster의 갯수가 더 많은 지 확인 후 생성하도록 합니다.

  

## Requirements

| Name      | Version |
| :-------- | :-----: |
| terraform | >= 0.12 |



## Providers

| Name | Version |
| :--- | :-----: |
| aws  | >= 4.00 |



## Resources

| Name                                                         |   Type   |
| :----------------------------------------------------------- | :------: |
| [aws_elasticache_parameter_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group) | resource |
| [aws_elasticache_subnet_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_elasticache_replication_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |



## Inputs

| Name                       | Description                                                  |      Type      |         Default          | Required |
| :------------------------- | :----------------------------------------------------------- | :------------: | :----------------------: | :------: |
| svc_name                   | VPC의 사용 용도                                               |    `string`    |                          |  `yes`   |
| purpose                    | VPC의 용도를 나타낼 수 있는 서비스 명 (ex, svc / mgmt)          |    `string`    |                          |  `yes`   |
| env                        | 시스템 구성 환경 (ex, dev / stg / prod)                        |    `string`    |                          |  `yes`   |
| region_name_alias          | 서비스 AWS Region alias (ex, ap-northeast-2 → kr)             |    `string`    |                          |  `yes`   |
| az_names                   | cluster instances를 설치할 availability zones                 | `list(string)` |                          |  `yes`   |
| replication_group_id       | ElastiCache(redis) replication group name                    |    `string`    |                          |  `yes`   |
| subnet_ids                 | Redis service subnet IDs (Redis instance를 생성시킬 subnets)  | `list(string)` |                          |  `yes`   |
| security_group_ids         | Redis service security group IDs                             | `list(string)` |                          |  `yes`   |
| parameter_group            | Redis parameter group                                        |    `string`    |                          |  `yes`   |
| node_type                  | redis node instance type                                     |    `string`    |                          |  `yes`   |
| num_cache_cluster          | non-cluster mode: replication group member no, cluster-mode: cluster sharding no |    `number`    |           `1`            |   `no`   |
| engine_version             | engine_version                                               |    `string`    |                          |  `yes`   |
| port                       | service port                                                 |    `number`    |          `8379`          |   `no`   |
| apply_immediately          | Apply configurations immediately                             |     `bool`     |          `true`          |   `no`   |
| auto_minor_version_upgrade | minor upgrade automatically                                  |     `bool`     |         `false`          |   `no`   |
| maintanence_window         | maintanence_window (UTC에 주의하여 시간 설정 필요)             |    `string`    |  `sat:15:00-sat:16:00`   |   `no`   |
| notification_topic_arn     | Event notification SNS topic ARN                             |    `string`    | `RollbackCapacityChange` |   `no`   |
| elasticache_parameters     | A list of ElastiCache parameters to apply                    |   `map(any)`   |           `{}`           |   `no`   |
| snapshot_retention_limit   | Number of days of ElastiCache automatic snapshots            |   `number`     |           `0`            |   `no`   |
| tags                       | ElastiCache tags                                             | `map(string)`  |           `{}`           |   `no`   |



## Outputs

| Name                   | Description                                 |
| :--------------------- | :------------------------------------------ |
| replication_group_arn  | ElastiCache(redis) replication group ARN    |
| replication_group_id   | ElastiCache(redis) replication group ID     |
| replication_group_port | ElastiCache(redis) service port             |
| redis_node_ids         | ElastiCache(redis) instance node IDs        |
| primary_endpoint       | ElastiCache(redis) service primary endpoint |
| read_endpoint          | ElastiCache(redis) service  read  endpoint  |
| engine_version_actual  | ElastiCache(redis) engine version           |