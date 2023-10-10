variable "vpc_id" {
    description = "VPC ID for EKS cluster"
    type = string
}

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

variable "cluster_name" {
    description = "AWS EKS cluster name"
    type = string
    default = "dks-cluster"    
}

variable "cluster_version" {
    description = "Desired Kubernetes master version, if null, latest version is used"
    type = string
    default = null
}

variable "cluster_role_arn" {
    description = "Cluster IAM role ARN"
    type = string
    default = null
}

variable "service_ipv4_cidr" {
    description = "The CIDR block to assign Kubernetes service IP addresses from(default: 10.100.0.0/16 or 172.20.0.0/16 CIDR blocks)"
    type = string
    default = null
}

variable "ingress_subnet_ids" {
    description = "subnets for EKS (include ingress network)"
    type = list(string)
    default = []
}

variable "security_group_ids" {
    description = "Additional cluster security groups"
    type = list(string)
    default = []
}

variable "enabled_cluster_log_types" {
    description = "Cluster api audit log types (api, audit, authenticator, controllerManager, scheduler)"
    type = list(string)
    default = []
}

variable "log_retention_in_days" {
    description = "Cluster api audit logging cloudwatch retention days"
    type = number
    default = 365
}

variable "log_kms_key_id" {
    description = "The ARN of the KMS Key to use when encrypting log data"
    type = string
    default = null
}

variable "endpoint_private_access" {
    description = "Whether the Amazon EKS private API server endpoint is enabled"
    type = bool
    default = true
}

variable "endpoint_public_access" {
    description = "Whether the Amazon EKS public API server endpoint is enabled"
    type = bool
    default = false
}

variable "public_access_cidrs" {
    description = "List of CIDR blocks. Indicates which CIDR blocks can access the Amazon EKS public API server endpoint"
    type = list(string)
    default = []
}

variable "encryption_provider_key_arn" {
    description = "ARN of the Key Management Service (KMS) customer master key (CMK)"
    type = string
    default = null
}

variable "encryption_resources" {
    description  = "List of strings with resources to be encrypted"
    type = list(string)
    default = null
}

variable "eks_cluster_admin_users" {
    description = "EKS cluster administrator (IAM arn)"
    type = list(string)
    default = []
}

variable "eks_cluster_readonly_users" {
    description = "EKS cluster readonly (IAM arn)"
    type = list(string)
    default = []
}

variable "eks_cluster_rbac_users" {
    description = "EKS cluster users (need to configure clusterrolebinding, rolebinding later)"
    type = any
    /*
    type = list(object({
        group = string #(Required) GroupName for Group kind of subjects in clusterrolebinding or rolebinding
        members = list(string) #(Required) IAM username list in this group
        policy = string #(Optional) rbac manifest for this group (clusterrole, clusterrolebinding, role, rolebinding)
    }))
    */
    default = []
}

variable "eks_cluster_admin_roles" {
    description = "EKS cluster administrator role (IAM arn)"
    type = list(string)
    default = []
}

variable "eks_cluster_readonly_roles" {
    description = "EKS cluster readonly (Role arn)"
    type = list(string)
    default = []
}

variable "eks_cluster_rbac_roles" {
    description = "EKS cluster roles (need to configure clusterrolebinding, rolebinding later)"
    type = any
    /*
    type = list(object({
        group = string #(Required) GroupName for Group kind of subjects in clusterrolebinding or rolebinding
        members = list(string) #(Required) IAM role arn list in this group
        policy = string #(Optional) rbac manifest for this group (clusterrole, clusterrolebinding, role, rolebinding)
    }))
    */
    default = []
}

### worker node group configuration ###
variable "nodegrp_subnet_ids" {
    description = "VPC subnet IDs for node groups"
    type = list(string)
}

variable "nodegrp_role_arn" {
    description = "role arn for nodes in nodegroup"
    type = string
}

variable "eks_node_groups" {
    description = "EkS node group configuration"
    type = any
    /*
    type = map(object({
        ami_type = string # Type of Amazon Machine Image (AMI) (AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | CUSTOM | BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64)
        capacity_type = string # The capacity type of your managed node group(ON_DEMAND | SPOT)
        instance_types = list(string) # Worker nodes instance types (list)
        cri_type = string #(Optional) dockerd or containerd (not specified => eks default)
        scaling_config = object({
            desired_size = number
            max_size = number
            min_size = number
        })
        update_config = object({
            max_unavailable = number
            max_unavailable_percentage = number
        })
        force_update_version = bool
        taint = object({
            key = string
            value = string
            effect = string
        })
        labels = list(string)

        # for launch template
        block_device_mappings = list(object({
            device_name = string
            volume_type = string
            volume_size = number
            iops = number
            throughput = number
            encrypted = bool
            kms_key_id = string
            snapshot_id = string
            delete_on_termination = bool
        }))
        disable_api_termination = bool
        key_name = string
        monitoring = bool
        vpc_security_group_ids = list(string)
        network_interfaces = list(object({
            associate_public_ip_address = bool
            private_ip_address = string
            delete_on_termination = bool
        }))
        tag_specifications = map(map(string))
    }))
    */
}

variable "use_container_insights" {
    description = "use container insights"
    type = bool
    default = true
}

variable "container_insights_log_groups" {
    description = "Container insights cloudwatch log groups"
    type = list(string)
    default = ["application", "dataplane", "host", "performance"]
}

variable "container_insights_additional_log_groups" {
    description = "Container insights cloudwatch Additional log groups"
    type = list(string)
    default = []
}

variable "eks_fargate_profiles" {
    description = "EkS fargate configuration" 
    type = any
    /* key => fargate_profile_name = string #(Required) Name of the EKS Fargate Profile
    type = map(object({
        role_arn = string #(Required) Name of the EKS Fargate Profile (assume role for eks-fargate-pods.amazonaws.com with AmazonEKSFargatePodExecutionRolePolicy policy)
        selectors = list(object({ #(Required) Configuration block(s) for selecting Kubernetes Pods to execute with this EKS Fargate Profile
            namespace = string #(Required) Kubernetes namespace for selection
            labels = map(string) # (Optional) Key-value map of Kubernetes labels for selection
        }))
        subnet_ids = list(string) #(Required) Identifiers of private EC2 Subnets to associate with the EKS Fargate Profile
        security_group_ids = list(string) #(Required) Security groups for fargate pods
        fargate_only = bool #(Optional) When only fargate is used (coreDNS will be created in fargate)
        tags = map(string) #(Optional) Key-value map of resource tags. If configured with a provider
    }))
    */
    default = {}
}

# works on eks.3 or later, Kubernetes 1.18 and later
variable "add_ons" {
    description = "EKS addons like aws-vpccni, coredns, kubeproxy, ebs csi driver etc"
    type = any
    /*
    type = list(object({
        name = string #(Required) Name of the EKS add-on (refer to https://docs.aws.amazon.com/cli/latest/reference/eks/list-addons.html)
        version = string #(Optional) The version of the EKS add-on. The version must match one of the versions
        resolve_conflicts = bool #(Optional) overwrite or not if same addons exist in cluster
        role_arn = string #(Optional) Service role arn for service account (refer to https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html)
                                          # 만일 service role arn이 지정되지 않으면, node에 할당된 service role을 사용함
        tags = map(string) #(Optional) resource tags
    }))*/
    default = []
}