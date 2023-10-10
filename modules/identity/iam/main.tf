/*  Resource Naming rule
    Policy: p_[purpose]_[env]_[region] ex) p_dplinst_prod_kr
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
    env = lower(var.env)
    region_name_alias = lower(var.region_name_alias)
    suffix = "${local.env}_${local.region_name_alias}"
    policies = toset(concat(flatten([ for role in var.roles: [ for name in try(role.policies, []): name ]]),
                            flatten([ for group_name, policies in var.groups: [ for name in policies: name ]]),
                            flatten([ for user_name, user_data in var.users: [ for name in try(user_data.policies, []): name ]])))
}

data "aws_caller_identity" "current" {}

########## 1. Create IAM Policies #######
data "template_file" "default" {
    for_each = { for k in fileset("${path.module}/policies", "*.json") : split(".", k)[0] => "${path.module}/policies/${k}" if var.create_default_policies }
    template = file(each.value)
    vars = { 
        ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
}
resource "aws_iam_policy" "main" {
    for_each = merge({ for k, v in data.template_file.default : k => v.rendered }, try(var.policies,{}))
    name = "p_${each.key}_${local.suffix}"
    policy = each.value
}

########## 2. Create IAM Roles and attatch policies #######
data "aws_iam_policy_document" "main" {
    for_each = var.roles
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type = each.value.type
            identifiers = each.value.identifiers
            /*
            identifiers = ( lower(each.value.type) != "aws" ? each.value.identifiers :
                            formatlist("arn:aws:iam::%s", [for v in each.value.identifiers: 
                                                length(regexall("[0-9]{12}:", v)) != 0 ? v : "${data.aws_caller_identity.current.account_id}:${v}" ])
                          )
            */
        }
    }
}
resource "aws_iam_role" "main" {
    for_each = var.roles
    name = "r_${each.key}_${local.suffix}"
    force_detach_policies = lookup(each.value, "force_detach_policies", false)
    assume_role_policy = data.aws_iam_policy_document.main[each.key].json
    tags = {
        Name = "r_${each.key}_${local.suffix}"
    }
    depends_on = [data.aws_iam_policy_document.main]
}


# get all infomation for builtin policies in this module
data "aws_iam_policy" "builtin" {
    # get all uniq policy_name in this module
    #for_each = { for k, v in local.policies: k => v if ! contains(keys(var.policies), k) ? "p_${k}_${local.suffix}" : v }
    for_each = { for k, v in local.policies: k => v if ! contains(keys(var.policies), k) && ! contains(keys(data.template_file.default), k) }
    arn = substr(each.value, 0, 7) == "arn:aws" ? each.value : null
    name = substr(each.value, 0, 7) != "arn:aws" ? each.value : null
    # depends_on 이 바뀌게 되면, 전체를 다시 읽어 드리며, 이렇게 되는 경우, aws_iam_role_policy_attachment replacement가 발생한다.!
    #depends_on = [aws_iam_policy.main]
}

resource "aws_iam_role_policy_attachment" "main" {
    for_each = merge([ for role_name, role in var.roles:
                        { for idx, policy_name in lookup(role, "policies", []): 
                            format("%s^%s", role_name, reverse(split("/", policy_name))[0]) => policy_name }
                     ]...)

    role = aws_iam_role.main[split("^", each.key)[0]].name
    policy_arn = contains(keys(aws_iam_policy.main), each.value) ? aws_iam_policy.main[each.value].arn : data.aws_iam_policy.builtin[each.value].arn
    #policy_arn = contains(keys(aws_iam_policy.main), each.value) ? aws_iam_policy.main[each.value].arn : "arn:aws:iam::aws:policy/${each.value}"
    depends_on = [aws_iam_role.main, aws_iam_policy.main]
}
resource "aws_iam_instance_profile" "main" {
    for_each = toset([for role_name in keys(var.roles): role_name if lookup(var.roles[role_name], "instance_role", false)])
    name = "rp_${each.key}_${local.suffix}"
    role = aws_iam_role.main[each.key].name
    tags = {
        Name: "rp_${each.key}_${local.suffix}"
    }
    depends_on = [aws_iam_role_policy_attachment.main, aws_iam_policy.main]
}

########## 3. Create IAM Groups and Users and attatch policies #######
resource "aws_iam_group" "iam_groups" {
    for_each = var.groups
    name = each.key
}

resource "aws_iam_group_policy_attachment" "iam_groups_policy_assoc" {
    # for_each에서 key에 할당되는 값이 dynamic한 변수라면, 오류발생 (키값으로 변수를 사용할 수 없음.)
    # 혹여나, 전달되는 variable에 한개라도 포함되어 있으면 에러가 발생한다.
    # ... 은 []안의 내용을 풀어서 전달하라는 의미
    # for문에 기본적으로 enumeration이 되므로, 변수만 할당하면 된다.
    for_each = merge([for group_name, policies in var.groups:
                        { for idx, policy_name in policies: format("%s^%s", group_name, reverse(split("/", policy_name))[0]) => policy_name }
                ]...)
    group = split("^", each.key)[0]
    policy_arn = contains(keys(aws_iam_policy.main), each.value) ? aws_iam_policy.main[each.value].arn : data.aws_iam_policy.builtin[each.value].arn
    #policy_arn = contains(keys(aws_iam_policy.main), each.value) ? aws_iam_policy.main[each.value].arn : "arn:aws:iam::aws:policy/${each.value}"
    depends_on = [aws_iam_group.iam_groups]
}
resource "aws_iam_user" "iam_users" {
    for_each = var.users
    name = each.key
    force_destroy = lookup(each.value, "force_destroy", false)
}
resource "aws_iam_user_group_membership" "iam_users_group_assoc" {
    for_each = var.users
    user = each.key
    groups = lookup(each.value, "groups", [])
    depends_on = [aws_iam_group.iam_groups, aws_iam_user.iam_users]
}
resource "aws_iam_user_policy_attachment" "iam_users_policy_assoc" {
    # for_each에서 key에 할당되는 값이 dynamic한 변수라면, 오류발생 (키값으로 변수를 사용할 수 없음.)
    # 혹여나, 전달되는 variable에 한개라도 포함되어 있으면 에러가 발생한다.
    # ... 은 []안의 내용을 풀어서 전달하라는 의미
    # for문에 기본적으로 enumeration이 되므로, 변수만 할당하면 된다.
    for_each = merge([ for user_name, rules in var.users: 
                        { for idx, policy_name in lookup(rules, "policies", []): format("%s^%s", user_name, reverse(split("/", policy_name))[0]) => policy_name }
                     ]...)
    
    user = split("^", each.key)[0]
    policy_arn = contains(keys(aws_iam_policy.main), each.value) ? aws_iam_policy.main[each.value].arn : data.aws_iam_policy.builtin[each.value].arn
    #policy_arn = contains(keys(aws_iam_policy.main), each.value) ? aws_iam_policy.main[each.value].arn : "arn:aws:iam::aws:policy/${each.value}"
    depends_on = [aws_iam_user.iam_users, aws_iam_policy.main]
}
resource "aws_iam_user_login_profile" "iam_login_users" {
    for_each = {for user_name in keys(var.users): user_name => true if lookup(var.users[user_name], "console_login", false)}
    user = each.key
    pgp_key = filebase64(var.encrypt_gpg)
    password_reset_required = true
    depends_on = [aws_iam_user.iam_users, aws_iam_user_policy_attachment.iam_users_policy_assoc]
    lifecycle {
        ignore_changes = [password_length, password_reset_required, pgp_key]
    }
}
resource "aws_iam_access_key" "iam_programmatic_users" {
    for_each = {for user_name in keys(var.users) : user_name => true if lookup(var.users[user_name], "programmatic_access", false)}
    user = each.key
    pgp_key = filebase64(var.encrypt_gpg)
    depends_on = [aws_iam_user.iam_users, aws_iam_user_policy_attachment.iam_users_policy_assoc]
    lifecycle {
        ignore_changes = [pgp_key]
    }
}
resource "aws_iam_account_password_policy" "strict_pwd_policy" {
    count = var.use_default_password_policy ? 1 : 0
    minimum_password_length        = 8
    require_lowercase_characters   = true
    require_numbers                = true
    require_uppercase_characters   = true
    require_symbols                = true
    allow_users_to_change_password = true
    password_reuse_prevention      = 2
    max_password_age               = 90
}