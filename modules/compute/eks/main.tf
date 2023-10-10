/* Resource Naming rule
    EKS-cluster: eks_cluster_[service_name]_[purpose]_[env]_[region] ex) eks_cluster_dks_prod_kr
    EKS-node: eks_workergrp_[service_name]_[purpose]_[env]_[region] ex) eks_workergrp_dks_prod_kr
*/
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
        # kubectl = {
        #     source = "gavinbunney/kubectl"
        #     version = "~> 1.14.0"
        # }
    }
}

# provider "kubectl" {
#     host = aws_eks_cluster.eks_cluster.endpoint
#     cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
#     exec {
#         api_version = "client.authentication.k8s.io/v1alpha1"
#         args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.id]
#         command     = "aws"
#     }
# }

locals {
    svc_name = lower(var.svc_name)
    purpose = lower(var.purpose)
    env = lower(var.env)
    region_name_alias = lower(var.region_name_alias)
    suffix = "${local.svc_name}_${local.purpose}_${local.env}_${local.region_name_alias}"
    account_id = data.aws_caller_identity.current.account_id
    asg_name_map = { for k, v in aws_eks_node_group.eks_cluster_node : k => v.resources[0].autoscaling_groups[0].name }
    
    # convert user_arn to user_name
    rbac_users = flatten([[ for user in var.eks_cluster_admin_users: { key = "${reverse(split("/", user))[0]}", value = "system:masters"} ],
                          [ for user in var.eks_cluster_readonly_users: { key = "${reverse(split("/", user))[0]}", value = "system:viewers"} ],
                          [ for v in var.eks_cluster_rbac_users: [for user in v.members: { key = "${reverse(split("/", user))[0]}", value = "${v.group}"} ]]])

    rbac_user_group_map = merge([ for username in distinct([ for rbac_user in local.rbac_users: rbac_user["key"] ]):
                                   { for rbac_user in local.rbac_users: username => rbac_user["value"]... if rbac_user["key"] == username }
                                ]...)
    
    # convert role_arn to role_name
    rbac_roles = flatten([[ for role in var.eks_cluster_admin_roles: { key = "${reverse(split("/", role))[0]}", value = "system:masters"} ],
                          [ for role in var.eks_cluster_readonly_roles: { key = "${reverse(split("/", role))[0]}", value = "system:viewers"} ],
                          [ for v in var.eks_cluster_rbac_roles: [for role in v.members: { key = "${reverse(split("/", role))[0]}", value = "${v.group}"} ]]])

    rbac_role_group_map = merge([ for rolename in distinct([ for rbac_role in local.rbac_roles: rbac_role["key"] ]):
                                   { for rbac_role in local.rbac_roles: rolename => rbac_role["value"]... if rbac_role["key"] == rolename }
                                ]...)

    # key=> apiVersion/namespace/name
    k8s_kubeconfig = templatefile("${path.module}/k8s_kubeconfig.tftpl", {
                    cluster_name = aws_eks_cluster.eks_cluster.id,
                    cluster_endpoint = aws_eks_cluster.eks_cluster.endpoint,
                    cluster_ca = aws_eks_cluster.eks_cluster.certificate_authority[0].data
                })
    
    k8s_manifests = templatefile("${path.module}/k8s_manifests.tftpl", {
                            rbac_policies = flatten([[ for v in var.eks_cluster_rbac_users : v.policy if can(v.policy) ],
                                                     [ for v in var.eks_cluster_rbac_roles : v.policy if can(v.policy) ]])
                            metadata = merge([ for v in values(var.eks_fargate_profiles) : 
                                            { for selector in v.selectors : selector.namespace => 
                                            [ try(selector.labels, {}), concat(v.security_group_ids, [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id])] } ]...)
                })
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster_auth" "current" {
    name = "eks_${var.cluster_name}_${local.suffix}"
    depends_on = [aws_eks_cluster.eks_cluster]
}

# cloudwatch log group retention period when enabled_cluster_log_types used 
resource "aws_cloudwatch_log_group" "eks_cluster" {
    count = length(var.enabled_cluster_log_types) > 0 ? 1 : 0
    name = "/aws/eks/eks_${var.cluster_name}_${local.suffix}/cluster"
    retention_in_days = var.log_retention_in_days
    kms_key_id = var.log_kms_key_id
    
    tags = {
        Name = "logs_${var.cluster_name}_${local.suffix}"
    }
}

# Create containerinsights log group for application, dataplane, host, performance 
resource "aws_cloudwatch_log_group" "container_insights" {
    for_each = var.use_container_insights ? toset(concat(var.container_insights_log_groups, var.container_insights_additional_log_groups)) : []
    name = "/aws/containerinsights/eks_${var.cluster_name}_${local.suffix}/${each.key}"
    retention_in_days = var.log_retention_in_days
    kms_key_id = var.log_kms_key_id
    
    tags = {
        Name = "logs_containerinsights_${each.key}_${local.suffix}"
    }
}

# Refer to the site before making launch_template for eks node group
# https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html
# Use launch_template but use managed AMI from AWS
data "template_cloudinit_config" "cri_bootstraps" {
    for_each = { for k, v in var.eks_node_groups: k => v.cri_type if can(v.cri_type) }
    base64_encode = true
    gzip = false

    part {
        content_type = "text/x-shellscript"
        content = <<-EOT
            #!/bin/bash
            sed -i '/^set -o errexit/a\\nexport CONTAINER_RUNTIME="${each.value}"' /etc/eks/bootstrap.sh
        EOT
    }
}
resource "aws_launch_template" "nodegrp" {
    for_each = var.eks_node_groups
    name_prefix = "lt_${each.key}_eks_"
    description = "EKS node group default Launch-Template"
    #instance_type = lookup(each.value, "instance_types", ["c55.xlarge"])[0] => conflict when updated (not permitted)
    update_default_version = true
    
    # CRI-O : containerd configuration (https://github.com/awslabs/amazon-eks-ami/issues/844)
    user_data = can(each.value.cri_type) ? data.template_cloudinit_config.cri_bootstraps[each.key].rendered : null
    
    dynamic "block_device_mappings" {
        for_each = lookup(each.value, "block_device_mappings", [{ device_name = "/dev/xvda" }])
        content {
            device_name = block_device_mappings.value.device_name
            ebs {
                volume_type = lookup(block_device_mappings.value, "volume_type", "gp2")
                volume_size = lookup(block_device_mappings.value, "volume_size", 20)
                iops = contains(["io1", "io2"], lookup(block_device_mappings.value, "volume_type", "gp2")) ? lookup(block_device_mappings.value, "iops", null) : null
                throughput = lookup(block_device_mappings.value, "volume_type", "gp2") == "gp3" ? lookup(block_device_mappings.value, "throughput", null) : null
                encrypted = lookup(block_device_mappings.value, "encrypted", true)
                kms_key_id = lookup(block_device_mappings.value, "kms_key_id", null)
                snapshot_id = lookup(block_device_mappings.value, "snapshot_id", null)
                delete_on_termination = lookup(block_device_mappings.value, "delete_on_termination", true)
            }
        }
    }
    disable_api_termination = lookup(each.value, "disable_api_termination", false)
    key_name = lookup(each.value, "key_name", null)
    monitoring {
        enabled = lookup(each.value, "monitoring", false)
    }
    # conflict with network_interfaces.security_groups
    vpc_security_group_ids = concat(lookup(each.value, "vpc_security_group_ids", []), [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id])
    dynamic "network_interfaces" {
        for_each = lookup(each.value, "network_interfaces", null) != null ? each.value.network_interfaces : []
        content {
            associate_public_ip_address = lookup(network_interfaces.value, "associate_public_ip_address", false)
            private_ip_address = lookup(network_interfaces.value, "private_ip_address", null)
            # conflict with vpc_security_group_ids
            security_groups = lookup(each.value, "vpc_security_group_ids", null) != null ? null : concat(lookup(network_interfaces.value, "security_groups", []), [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id])
            delete_on_termination = lookup(network_interfaces.value, "delete_on_termination", true)
        }
    }
    dynamic "tag_specifications" {
        for_each = lookup(each.value, "tag_specifications", null) != null ? each.value.tag_specifications : {}
        content {
             resource_type = tag_specifications.key
             tags = tag_specifications.value
        }
    }
    tags = {
        Name = "lt_${each.key}_eks_${local.suffix}"
    }
    lifecycle { 
        create_before_destroy = true
    }
    depends_on = [aws_eks_cluster.eks_cluster, data.template_cloudinit_config.cri_bootstraps]
}

resource "aws_eks_cluster" "eks_cluster" {
    name = "eks_${var.cluster_name}_${local.suffix}"
    role_arn = var.cluster_role_arn
    version = var.cluster_version

    enabled_cluster_log_types = var.enabled_cluster_log_types
    # private EKS (only on private VPC)
    vpc_config {
        subnet_ids  = var.nodegrp_subnet_ids
        # additional security group ids not cluster security group, cluster security group is automatically created
        security_group_ids = var.security_group_ids
        endpoint_private_access = var.endpoint_private_access
        endpoint_public_access = var.endpoint_public_access
        public_access_cidrs = var.endpoint_public_access ? var.public_access_cidrs : null
    }
    # k8s service ip cidr    
    dynamic "kubernetes_network_config" {
        for_each = var.service_ipv4_cidr != null ? [var.service_ipv4_cidr] : []
        content {
            service_ipv4_cidr = var.service_ipv4_cidr
        }
    }
    dynamic "encryption_config" {
        for_each = var.encryption_provider_key_arn != null && var.encryption_resources != null ? [1] : []
        content {
            provider {
                key_arn = var.encryption_provider_key_arn
            }
            resources = var.encryption_resources
        }
    }
    tags = {
        # Naming rule: eks_cluster_[service_name]_[purpose]_[env]_[region] ex) eks_cluster_dks_prod_kr
        Name = format("eks_cluster_%s", local.suffix)
    }
    
    provisioner "local-exec" {
        command = <<-EOF
            echo "Revoke egress anyopen security group from eks cluster security group"
            aws ec2 revoke-security-group-egress --group-id $SECURITY_GROUP_ID --protocol all --cidr "0.0.0.0/0"
            echo "Add egress security group for source security group $SECURITY_GROUP_ID"
            aws ec2 authorize-security-group-egress --group-id $SECURITY_GROUP_ID --protocol all --source-group $SECURITY_GROUP_ID
            aws ec2 create-tags --resources $SECURITY_GROUP_ID --tags "Key=Name,Value=$TAG"
        EOF
        on_failure = continue
        environment = {
            SECURITY_GROUP_ID = self.vpc_config[0].cluster_security_group_id
            TAG = "sk_${var.cluster_name}_${local.suffix}"
        }
    }

    # Delete security group created by EKS automatically
    # Destroy-time provisioners an only run if they remain in the configuration at the time a resource is destroyed
    # security groups automatically generated by EKS can not be delete at this time because of resource dependency
    provisioner "local-exec" {
        when = destroy
        command = <<-EOF
            echo "Security Group Automatically generated by EKS should be deleted manually after cluster destruction"
            echo "Please delete manually using aws cli command or AWS web console"
            echo "aws ec2 delete-security-group --group-id ${self.vpc_config[0].cluster_security_group_id}"
        EOF
        on_failure = continue
    }

    depends_on = [aws_cloudwatch_log_group.eks_cluster]
}

# Use launch template
resource "aws_eks_node_group" "eks_cluster_node" {
    for_each = var.eks_node_groups
    
    cluster_name    = aws_eks_cluster.eks_cluster.name
    node_group_name = replace("nodegrp_${each.key}_${local.suffix}", "_", "-")
    
    ami_type = lookup(each.value, "ami_type", "AL2_x86_64")
    capacity_type = lookup(each.value, "capacity_type", "ON_DEMAND")
    instance_types = lookup(each.value, "instance_types", ["c5.xlarge"])

    node_role_arn   = var.nodegrp_role_arn
    subnet_ids      = var.nodegrp_subnet_ids
    
    force_update_version = lookup(each.value, "force_update_version", true)
    
    scaling_config {
        desired_size = each.value.scaling_config.desired_size
        max_size = each.value.scaling_config.max_size
        min_size = each.value.scaling_config.min_size
    }
    update_config {
        max_unavailable = lookup(each.value.update_config, "max_unavailable", null)
        max_unavailable_percentage = lookup(each.value.update_config, "max_unavailable_percentage", null)
    }
    
    dynamic "taint" {
        for_each = lookup(each.value, "taint", null) != null ? each.value.taint : []
        content {
            key = taint.value.key
            effect = lookup(taint.value, "effect", null)
            value = lookup(taint.value, "value", null)
        }
    }

    labels = lookup(each.value, "labels", null)
    launch_template {
        version = aws_launch_template.nodegrp[each.key].latest_version
        id = aws_launch_template.nodegrp[each.key].id
    }
    
    tags = {
        # Naming rule: eks_workergrp_[service_name]_[purpose]_[env]_[region] ex) eks_workergrp_dks_svc_prod_kr
        Name = format("eks_workergrp_%s", local.suffix)
    }
    
    # if CAS(Cluster Auto scaler) is used, desired_size used to be changed, by CAS, so desired_size has to be ignored.
    # lifecycle block is meta block, so it cannot be applied conditionally
    lifecycle {
        ignore_changes = [scaling_config[0].desired_size]
    }
    depends_on = [aws_eks_cluster.eks_cluster, aws_launch_template.nodegrp]
}

data "tls_certificate" "eks_cluster" {
    url = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
    depends_on = [aws_eks_cluster.eks_cluster]
}

# Create EKS open id connect provider
resource "aws_iam_openid_connect_provider" "eks_cluster" {
    client_id_list = ["sts.amazonaws.com"]
    thumbprint_list = [data.tls_certificate.eks_cluster.certificates.0.sha1_fingerprint]
    url = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
    depends_on = [aws_eks_cluster.eks_cluster]
}

# Add tags to vpc and subnets "kubernetes.io/cluster/${var.cluster_name}" = "shared",
resource "aws_ec2_tag" "vpc_tags" {
    resource_id = var.vpc_id
    key = "kubernetes.io/cluster/${aws_eks_cluster.eks_cluster.id}"
    value = "shared"
    depends_on = [aws_eks_cluster.eks_cluster]
}

resource "aws_ec2_tag" "ingress_tags" {
    # for_each key에 not applied resource variable을 넣을 수 없음.
    for_each = merge([ for idx, subnet_id in var.ingress_subnet_ids: {
                    for k, v in { "kubernetes.io/cluster/<YOUR_CLUSTER_ID>" = "shared", "kubernetes.io/role/elb" = "1", "kubernetes.io/role/internal-elb" = "1" }:
                        join("^", ["subnet-${idx}", k, v]) => subnet_id }]...)
                
    resource_id = each.value
    key = replace(split("^", each.key)[1], "<YOUR_CLUSTER_ID>", aws_eks_cluster.eks_cluster.id)
    value = split("^", each.key)[2]
    depends_on = [aws_eks_cluster.eks_cluster]
}

### Tagging to Autoscale group for cluster-autoscale (autoscale group auto discovery)
resource "aws_autoscaling_group_tag" "asg_tags" {
    for_each = merge([ for nodegrp_name in keys(var.eks_node_groups) : {
                   for k, v in {"k8s.io/cluster-autoscaler/<YOUR_CLUSTER_ID>" = "owned", "k8s.io/cluster-autoscaler/enabled" = "TRUE"}: 
                        join("^", [nodegrp_name, k, v]) => nodegrp_name
                }]...)
      
    autoscaling_group_name = local.asg_name_map[each.value]
    tag {
        key = replace(split("^", each.key)[1], "<YOUR_CLUSTER_ID>", aws_eks_cluster.eks_cluster.id)
        value = split("^", each.key)[2]
        propagate_at_launch = true
    }
    depends_on = [aws_eks_node_group.eks_cluster_node]
}
resource "aws_eks_fargate_profile" "main" {
    for_each = var.eks_fargate_profiles
    
    fargate_profile_name = "fargate_${each.key}_${local.suffix}"
    cluster_name = aws_eks_cluster.eks_cluster.id
    pod_execution_role_arn = each.value.role_arn
    dynamic "selector" {
        for_each = each.value.selectors
        content {
            namespace = selector.value.namespace
            labels = try(selector.value.labels, {})
        }
    }
    subnet_ids = each.value.subnet_ids
    tags = merge(try(each.value.tags, {}), {Name = "fargate_${each.key}_${local.suffix}"})

    # coreDNS가 fargate에서 뜨게 할 경우 (즉, fargate only로 사용할 경우에 해당)
    provisioner "local-exec" {
        interpreter = ["/bin/bash", "-c"]
        command = <<-EOF
            if ${try(each.value.fargate_only, false)}; then
                chmod +x "${path.module}/k8s_restapi.sh"
                "${path.module}/k8s_restapi.sh" PATCH
            fi
        EOF
        environment = {
            CLUSTER_ID = aws_eks_cluster.eks_cluster.id
            API_SERVER = aws_eks_cluster.eks_cluster.endpoint
            API_VERSION = "apis/apps/v1"
            KIND = "Deployment"
            NAMESPACE = "kube-system"
            NAME = "coredns"
            MANIFEST = jsonencode([ {"op" = "remove", "path" = "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"} ])
        }
        on_failure = continue
    }

    depends_on = [aws_eks_cluster.eks_cluster]
}

// CTA 과정에선 IAM User가 고정되기 때문에 미사용 예정
# resource "null_resource" "k8s_awsauth" {
#     for_each = { "v1^ConfigMap^kube-system^aws-auth" = "${path.module}/k8s_awsauth.tftpl"}
#     triggers = {
#         cluster_id = aws_eks_cluster.eks_cluster.id
#         api_server = aws_eks_cluster.eks_cluster.endpoint
#         api_version = split("/", split("^", each.key)[0])[0] == "v1" ? "api/v1" : "apis/${split("^", each.key)[0]}"
#         kind = split("^", each.key)[1]
#         namespace = split("^", each.key)[2]
#         name = split("^", each.key)[3]
#         manifest = templatefile(each.value, {
#                         nodegrp_role_arn = var.nodegrp_role_arn,
#                         account = "arn:aws:iam::${local.account_id}",
#                         rbac_roles = local.rbac_role_group_map,
#                         rbac_users = local.rbac_user_group_map
#                     })
#     }
#     provisioner "local-exec" {
#         when = destroy
#         command = <<-EOF
#             chmod +x "${path.module}/k8s_restapi.sh"
#             "${path.module}/k8s_restapi.sh" DELETE
#         EOF
#         environment = {
#             CLUSTER_ID = self.triggers.cluster_id
#             API_SERVER = self.triggers.api_server
#             API_VERSION = self.triggers.api_version
#             KIND = self.triggers.kind
#             NAMESPACE = self.triggers.namespace
#             NAME = self.triggers.name
#         }
#     }
#     provisioner "local-exec" {
#         command = <<-EOF
#             chmod +x "${path.module}/k8s_restapi.sh"
#             "${path.module}/k8s_restapi.sh" CREATE
#         EOF
#         environment = {
#             CLUSTER_ID = self.triggers.cluster_id
#             API_SERVER = self.triggers.api_server
#             API_VERSION = self.triggers.api_version
#             KIND = self.triggers.kind
#             NAMESPACE = self.triggers.namespace
#             NAME = self.triggers.name
#             MANIFEST = self.triggers.manifest
#         }
        
#         on_failure = fail
#     }
#     depends_on = [aws_eks_cluster.eks_cluster]
# }

// CTA 과정에선 IAM User가 고정되기 때문에 미사용 예정
# resource "null_resource" "k8s_resource" {
#     for_each = { for idx, manifest in split("---", local.k8s_manifests) :
#                  "${join("^", [ "${yamldecode(manifest)["apiVersion"]}",
#                                 "${yamldecode(manifest)["kind"]}",
#                                 "${contains(keys(yamldecode(manifest)["metadata"]),"namespace") ? yamldecode(manifest)["metadata"]["namespace"] : "default" }",
#                                 "${yamldecode(manifest)["metadata"]["name"]}" ])}" => trimprefix(manifest, "\n") if manifest != "" }
#     triggers = {
#         cluster_id = aws_eks_cluster.eks_cluster.id
#         api_server = aws_eks_cluster.eks_cluster.endpoint
#         api_version = split("/", split("^", each.key)[0])[0] == "v1" ? "api/v1" : "apis/${split("^", each.key)[0]}"
#         kind = split("^", each.key)[1]
#         namespace = split("^", each.key)[2]
#         name = split("^", each.key)[3]
#         manifest = replace(each.value, "{{nodegrp_role_arn}}", var.nodegrp_role_arn)
#     }
#     provisioner "local-exec" {
#         when = destroy
#         command = <<-EOF
#             chmod +x "${path.module}/k8s_restapi.sh"
#             "${path.module}/k8s_restapi.sh" DELETE
#         EOF
#         environment = {
#             CLUSTER_ID = self.triggers.cluster_id
#             API_SERVER = self.triggers.api_server
#             API_VERSION = self.triggers.api_version
#             KIND = self.triggers.kind
#             NAMESPACE = self.triggers.namespace
#             NAME = self.triggers.name
#         }
#     }
#     provisioner "local-exec" {
#         command = <<-EOF
#             chmod +x "${path.module}/k8s_restapi.sh"
#             "${path.module}/k8s_restapi.sh" CREATE
#         EOF
#         environment = {
#             CLUSTER_ID = self.triggers.cluster_id
#             API_SERVER = self.triggers.api_server
#             API_VERSION = self.triggers.api_version
#             KIND = self.triggers.kind
#             NAMESPACE = self.triggers.namespace
#             NAME = self.triggers.name
#             MANIFEST = self.triggers.manifest
#         }
        
#         on_failure = fail
#     }
#     depends_on = [aws_eks_cluster.eks_cluster]
# }

# resource "kubectl_manifest" "main" {
#     # 테라폼의 map은 자동 sort하기 때문에, 순서가 중요한 명령어 set을 실행시킬때 주의가 필요. (list권장하나, list사용시 순서가 변경되면 전체 resource를 재 생성하는 문제가 있음)
#     # 본 모듈에서 사용하는 manifest set은 다행히 적용 가능함
#     # kubernetes_manifests를 사용하지 않는 이유는 https://medium.com/@danieljimgarcia/dont-use-the-terraform-kubernetes-manifest-resource-6c7ff4fe629a
#     for_each = { for idx, manifest in split("---", local.k8s_manifests ) :
#                  "${join("^", [ "${yamldecode(manifest)["apiVersion"]}",
#                                 "${yamldecode(manifest)["kind"]}",
#                                 "${contains(keys(yamldecode(manifest)["metadata"]),"namespace") ? yamldecode(manifest)["metadata"]["namespace"] : "default" }",
#                                 "${yamldecode(manifest)["metadata"]["name"]}" ])}" => trimprefix(manifest, "\n") if manifest != "" }
#     yaml_body = each.value
# }

resource "aws_eks_addon" "main" {
# works on eks.3 or later, Kubernetes 1.18 and later
    for_each = { for v in var.add_ons : v.name => v }
    cluster_name  = aws_eks_cluster.eks_cluster.id
    addon_name = each.key
    addon_version = try(each.value.version, null) # Use default version
    resolve_conflicts = try(each.value.resolve_conflicts, "OVERWRITE") # OVERWRITE or NONE
    service_account_role_arn = try(each.value.role_arn, null) # 만일 설정하지 않으면, worker node의 Service role을 사용
    tags = try(each.value.tags, {})
}