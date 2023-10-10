# AWS iam Module

iam 모듈은 module/identity/iam_policy, module/identity/iam_role, module/identity/iam_user 3개의 module을 합친 모듈입니다.

- IAM policy는 AWS Resource에 대해 접근 권한을 부여하는 기능이므로, 주의하여 사용하여야 합니다.<br> 보안권고상 기본적으로 생성해야 하는 policy가 있는데 다음과 같으며, 모듈 directory내 policies directory에 json의 형식으로 저장되어 있습니다. 

  | Policy 이름          | 설명                                                         |
  | -------------------- | ------------------------------------------------------------ |
  | ForceMFARestriction  | AWS Resource 접근시 해당 사용자가 MFA 가상 device를 등록했는지 확인 후, MFA 사용자만 접근허용 |
  | logs                 | Cloudwatch log group, stream을 사용하기 위한 정책 (VPC flow-log 등에 사용됨) |
  | ManageOwnAccount     | 사용자 본인이 본인 account에 대한 정보(Password, secret key, MFA 등)를 변경할 수 있도록 하는 정책 |

- IAM policy들을 IAM Role에 추가하고 이 Role을 IAM Account, AWS Service,  Instance에 할당하여, AWS Resource에 접근이 가능하도록 합니다.<br>IAM Role에 할당할 수 있는 Policy의 갯수가 default 10개로 제한되어 있으며, 필요시 [이곳](https://ap-northeast-2.console.aws.amazon.com/servicequotas/home/services)을 통해 Quota를 변경하도록 합니다. <br> 

- 또한, 보안에서 기본으로 권고하는 패스워드 정책이 다음과 같이 기본 설정되어 있습니다.

  | 파라메터                       |   값   | 비고                                    |
  | ------------------------------ | :----: | --------------------------------------- |
  | minimum_password_length        |  `8`   | 패스워드의 최소길이                     |
  | require_lowercase_characters   | `true` | 패스워드에 소문자 포함                  |
  | require_numbers                | `true` | 패스워드에 숫자 포함                    |
  | require_uppercase_characters   | `true` | 패스워드에 대문자 포함                  |
  | require_symbols                | `true` | 패스워드에 특수기호 포함                |
  | allow_users_to_change_password | `true` | 사용자에 패스워드 변경 허용             |
  | password_reuse_prevention      |  `2`   | 패스워드 재사용 금지 (최소 2개 histroy) |
  | max_password_age               |  `90`  | 패스워드 교환 주기 (일)                 |

AWS IAM 에 대한 자세한 내용은 아래의 AWS 문서를 참고하도록 합니다.

>  ✔  [`AWS IAM_Policy`](https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/access_policies.html) - 정책을 생성하고 IAM 자격 증명(사용자, 사용자 그룹 또는 역할) 또는 AWS 리소스에 연결하여 AWS에서 액세스를 관리합니다. 
>  정책은 자격 증명이나 리소스와 연결될 때 해당 권한을 정의하는 AWS의 객체입니다
>
>  ✔  [`AWS IAM_role`](https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/id_roles.html) - IAM 역할은 계정에 생성할 수 있는, 특정 권한을 지닌 IAM 자격 증명입니다. AWS에서 자격 증명이 할 수 있는 것과 없는 것을 결정하는 권한 정책을 갖춘 AWS 자격 증명이라는 점에서 IAM 역할은 IAM 사용자와 유사합니다
>
>  ✔  [`AWS IAM_user`](https://docs.ahttps://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/id_users.html) - AWS Identity and Access Management(IAM) 사용자는 AWS에서 생성하는 엔터티로서 AWS와 상호 작용하기 위해 해당 엔터티를 사용하는 사람 또는 애플리케이션을 나타냅니다. AWS에서 사용자는 이름과 자격 증명으로 구성됩니다



아래와 같은 이유로 3개의 모듈을 병합하게 되었으며, 사용방식이 아래와 같은 경우, 3개의 모듈을 별도로 사용하기 보다는 본 모듈 하나를 사용하는 것을 권장합니다.

```yaml
module "iam_policies" {
    source = "../../../modules/users/iam-policy"
    env = "stg"
    region_name_alias = "kr"
    policies = { for k, v in data.template_file.iam_policies : k => v.rendered }
    depends_on = [data.template_file.iam_policies]
}
module "iam_roles" {
    source = "../../../modules/users/iam-role"
    env = "stg"
    region_name_alias = "kr"
    roles = {
        flogs = {
            type = "Service"
            identifiers = ["vpc-flow-logs.amazonaws.com"]
            policies = ["ReadOnlyAccess", module.iam_policies.arn_map["logs"]] <= ** 모듈을 따로 쓰는 경우, 여기서 문제 발생 **
        }
    }
}
```

위의 코드에서 module.iam_roles.roles.policies = [module.iam_policies.arn_map["logs"]] 이 부분은, 아직 생성되지 않은 자원을 변수로 참조하는 부분으로, 
terraform 입장에서는 module.iam_policies 모듈에서 몇개의 arn을 제공할지 사전에 알 수가 없기 때문에 에러가 발생합니다. <br>이 부분은 iam_role 모듈의 코드가 아래와 같기 때문에 발생한다. 

```json
resource "aws_iam_group_policy_attachment" "iam_groups_policy_assoc" {
    for_each = merge([for group_name, policies in var.groups:
                        { for idx, policy_name in policies: format("%s^%s", group_name, reverse(split("/", policy_name))[0]) => policy_name }
                ]...)
    group = split("^", each.key)[0]
    policy_arn = contains(keys(aws_iam_policy.main), each.value) ? aws_iam_policy.main[each.value].arn : data.aws_iam_policy.builtin[each.value].arn
    depends_on = [aws_iam_group.iam_groups]
}
```

위의 코드에서 aws_iam_role_policy_attachment.main resource의 key는  index number 또는 key string을 사용할 수 있습니다. (aws_iam_role_policy_attachment.main[**"index"**], aws_iam_role_policy_attachment.main[**"key"**]) <br>만일, index number로 관리되는 경우, terraform에서 자원 변경 시, configuration 순서가 바뀌게 되는 경우, 자원의 index위치가 달라져, resource를 삭제/생성을 불필요하게 수행하는 문제점이 발생합니다. 
예를 들자면,  policies = ["ReadOnlyAccess", module.iam_policies.arn_map["logs"]] => policies = [module.iam_policies.arn_map["logs"], "ReadOnlyAccess"] 된다면 이미 자원이 있더라도 자원을 삭제/생성 하게 되는 것입니다. <br>따라서 Resource의 키를 index number로 관리하는 것 보다는 key string을 사용하는 것이 바람직하며,  iam-policy, iam-role, iam-user 모듈도 동일하게 모두 key string을 사용합니다. <br>위의 코드에서 module.iam_roles.roles.policies = [module.iam_policies.arn_map["logs"]] 부분은 key string이 "flogs^logs"가 되며,  <br>policy_arn을 할당하는 부분에서 아직 생성되지 않은 logs policy에 대한 ARN을 요청하므로, 오류가 발생하게 되는 것입니다.



## 인프라 사전 준비사항

다음의 인프라가 사전에 설치되어 있어야만, 본 모듈을 사용하여 자원을 생성할 수 있습니다.

| AWS 인프라 |                          간단 설명                           | Required |   사용 가능 모듈    |
| :--------: | :----------------------------------------------------------: | :------: | :-----------------: |
| IAM Policy | [권한을 정의하는 AWS의 객체](https://docs.aws.amazon.com/ko_kr/IAM/latest/UserGuide/access_policies.html) |   `no`   | identity/iam_policy |



## 사용예시

아래의 코드로 IAM policy, role, group/user들을 생성할 수 있습니다. (※ 아래의 예시 코드에서는 이해를 돕기 위해 변수대신 값을 사용하였으며, 대부분 변수를 사용합니다.)

```yaml
data "template_file" "iam_policies" { # json policy file을 Load
    for_each = { for k in fileset("${path.module}/iam_policies", "*.json") : split(".", k)[0] => "${path.module}/iam_policies/${k}" }
    template = file(each.value)
    vars = {}
}
module "iam" {
    source = "../../../modules/users/iam"
    env = "stg"
    region_name_alias = "kr"
    policies = { for k, v in data.template_file.iam_policies : k => v.rendered } # <= Load한 policy data를 입력 (iam_policy)
    roles = { # <= IAM Role 생성(iam_role)
        ec2-mgmt = {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
            policies = ["AWSCodeCommitFullAccess"]
            instance_role = true
        }
        eks = {
            type = "Service"
            identifiers = ["eks.amazonaws.com"]
            policies = ["AmazonEKSClusterPolicy", "AmazonEKSVPCResourceController"]
        }
        eksnode = {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
            policies = [
                "AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy", "AmazonEC2ContainerRegistryReadOnly",
                "AmazonS3FullAccess", "AmazonSQSFullAccess",  "AmazonCognitoPowerUser",
                "CloudWatchFullAccess", "AmazonSNSFullAccess", "AWSCloudHSMFullAccess",
                "CloudWatchAgentServerPolicy", "eks-ingressctrl", "eks-autoscale", "eks-externaldns"
            ]
        }
        securityaudit = {
            type = "AWS"
            identifiers = ["079645131663:root", "651726484220:root"]
            policies = ["SecurityAudit", "ReadOnlyAccess"]
        }
    }
    groups = { # <= IAM group 생성(iam_user)
        admin = ["AdministratorAccess"]
        dba = ["AmazonRDSFullAccess", "ReadOnlyAccess", "AmazonElastiCacheFullAccess"]
        users = ["ReadOnlyAccess"]
    }
    users = { # <= IAM user 생성(iam_user)
        "sample@sample.com" = {
            groups = ["admin"]
            policies = ["ForceIpRestriction", "ForceMFARestriction", "EC2AccessRestriction"]
            console_login = true
            programmatic_access = true
            force_destroy = true
        }
    }
    encrypt_gpg = "${path.module}/.sec/dks_stg_kr.gpg"
}
```

- svc_name, purpose, env, region_name_alias와 같은 variable들은 tag를 생성할 때 suffix로 사용됩니다.

  > Policy Name: p\_[policy_name(file name)]\_[env]\_[region] ex) p_logs_dev_kr
  >
  > Role Name: r\_[role_name]\_[env]\_[region] ex) r_logs_stg_kr

- policy 파일은 terraform의 data.aws_policy_document 로 처리하기에는 내용이 많기 때문에 본 모듈에서는 json형태의 파일로 관리합니다.
  파일의 이름이 policy의 이름이 되고, json 파일을 data.template_file로 load한 후, rendered 데이터를 map(string)의 형태로 모듈의 policies variable로 전달하여 처리합니다.

- policies variable에 전달되는 값은 map(string)의 형태로 ({"이름" : "정책"})의 형식입니다.

- Role에 할당되는 policies에는 AWS default policy 이름, 직접 생성한 policy 이름, ARN 모두 입력이 가능하다.

  > AWS default policy name: service-role/AWSBackupServiceRolePolicyForBackup, AmazonEKSWorkerNodePolicy 등
  >
  > 직접 생성한 custom policy name: eks-autoscale, logs 등
  >
  > policy ARN: arn:aws:iam::\*\*\*\*\*\*:policy/p_eks-autoscale_stg_kr, arn:aws:iam::\*\*\*\*\*\*:policy/p_logs_stg_kr 등

- terraform은 tfstate파일에 access key, secret key를 그대로 기록하게 되고, 보안상 문제가 발생할 수 있기 때문에 OS에서 생성한 gpg key를 기반으로 중요 내용을 암호화 저장합니다. encrypt_gpg에 해당 키의 위치를 설정합니다.

  - encrypt 설정 및 키관리 방법

    ```bash
    gpg --gen-key # interactive하게 설정하며, passphrase를 설정 하지 않을 수 있다.(설정하지 않아야 좀 더 편리함)
    gpg --password <name> # 만일, 패스워드를 설정했다면, passphrase 삭제 가능
    gpg --export <name> > <file_name> # ex) gpg --export dks.stg > .sec/dks_stg_kr.gpg
    gpg --export-secret-key <name> > <file_name> # ex) gpg --export-secret-key dks.stg > .sec/dks_stg_kr_sec.gpg
    gpg --list-keys # public key를 list-up
    gpg --list-secret-keys # private(secret) key를 list-up
    gpg --delete-key <name> # 특정 public key를 삭제
    gpg --delete-secret-key <name> #특정 private(secret) key를 삭제
    gpg --import <key file> # public/private key import
    ```

  - decrypt 방법 

    ```bash
    terraform output password | base64 --decode | gpg -q --decrypt; echo
    ```

  *<font color=red>secret key는 별도의 안전한 공간에 보관해야 합니다.</font>*

  

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
| [template_file](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) |   data   |
| [aws_iam_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_caller_identity](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) |   data   |
| [aws_iam_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) |   data   |
| [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group) | resource |
| [aws_iam_group_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_group_policy_attachment) | resource |
| [aws_iam_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [aws_iam_user_group_membership](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_group_membership) | resource |
| [aws_iam_user_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [aws_iam_user_login_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_login_profile) | resource |
| [aws_iam_access_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_account_password_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |



## Inputs

| Name                            | Description                                                  |        Type         | Default | Required |
| :------------------------------ | :----------------------------------------------------------- | :-----------------: | :-----: | :------: |
| env                             | 시스템 구성 환경 (ex, dev / stg / prod)                      |      `string`       |         |  `yes`   |
| region_name_alias               | 서비스 AWS Region alias (ex, ap-northeast-2 → kr)            |      `string`       |         |  `yes`   |
| create_default_policies         | default policy for 생성 여부 (ForceMFARestriction, logs, ManageOwnAccount) |       `bool`        | `true`  |   `no`   |
| policies                        | policy map 정의                                              |    `map(string)`    |  `{}`   |  `yes`   |
| **roles**                       | Role 정의                                                    |        `any`        |         |  `yes`   |
| **roles**.type                  | Role을 사용할 type (AWS, Service 등)                         |      `string`       |         |  `yes`   |
| **roles**.identifiers           | Role을 사용할 주체 (principals) 정의                         |   `list(string)`    |         |  `yes`   |
| **roles**.policies              | Role에 할당할 policy 리스트                                  |   `list(string)`    |         |  `yes`   |
| **roles**.instance_role         | instance에 사용할 Role 인지 여부                             |       `bool`        | `false` |   `no`   |
| **roles**.force_detach_policies | 강제로 policy detach 가능여부                                |       `bool`        | `false` |   `no`   |
| groups                          | IAM user group을 정의                                        | `map(list(string))` |  `{}`   |   `no`   |
| **users**                       | 사용자 계정을 정의                                           |        `any`        |  `{}`   |  `yes`   |
| **users**.groups                | 사용자에 할당할 group을 정의                                 |   `list(string)`    |  `[]`   |   `no`   |
| **users**.policies              | 사용자에 할당할 policy를 정의                                |   `list(string)`    |  `[]`   |   `no`   |
| **users**.console_login         | Console 사용자 계정인지 여부                                 |       `bool`        | `true`  |   `no`   |
| **users**.force_destroy         | 사용자 계정을 강제로 삭제할 수 있는지 여부                   |       `bool`        | `true`  |   `no`   |
| **users**.programmatic_access   | programmatic 계정인지 여부 (secret key발급)                  |       `bool`        | `false` |   `no`   |
| encrypt_gpg                     | secret key를 암호화 할 gpg public key                        |      `string`       |         |  `yes`   |
| use_default_password_policy     | default strict password policy를 사용할지 여부 설정          |       `bool`        | `true`  |   `no`   |


**`roles`** - roles input variable은 아래와 같은 구조로 구성되어 있다. (실제 variable type은 any이나 아래와 같은 형식으로 사용되고 있음을 참고)

```yaml
type = map(object({ #(Required)
    type = string #(Required)
    identifiers = list(string) #(Required)
    policies = list(string) #(Required)
    instance_role = bool #(Optional)
    force_detach_policies = bool #(Optional)
}))
```

**`users`** - users input variable은 아래와 같은 구조로 구성되어 있다. (실제 variable type은 any이나 아래와 같은 구조로 사용됨을 참고)

```yaml
type = map(object({ #(Required)
   groups = list(string) #(Optional)
   policies = list(string) #(Optional)
   console_login = bool #(Optional)
   programmtic_access = bool #(Optional)
}))
```



## Outputs

| Name                | Description                                                  |
| :------------------ | :----------------------------------------------------------- |
| policy_arn_map      | 생성된 policy의 이름(alias name)과 ARN의 mapping table       |
| policy_name_map     | 생성된 policy의 이름(alias name)과 name의 mapping table      |
| role_arn_map        | 생성된 role 의 이름과 ARN의 mapping table                    |
| inst_profile_id_map | 생성된 instance role의 이름과 ARN의 mapping table            |
| user_pwd_map        | 생성된 console 사용자의 임시 password ({사용자ID = 임시패스워드}) |
| user_secret_map     | 생성된 programmatic 사용자의 access_key, secret_key ({사용자ID = [access_key, secret_key]}) |