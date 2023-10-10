variable "env" {
    description = "Stage (dev, stg, prod etc)"
    type = string
}

variable "region_name_alias" {
    description = "AWS VPC region name alias like KR"
    type = string
}

variable "create_default_policies" {
    description = "whether create default policies or not"
    type = bool
    default = true
}

variable "policies" {
    description = "Policies"
    type = map(string) # name = json content
    default = {}
}

variable "roles" {
    description = "Roles to create"
    type = any
    default = {}
    /*
    type = map(object({
        type = string
        identifiers = list(string)
        policies = list(string)
        instance_role = bool
    }))
    */
    /* sample configuration
    default = {
        ec2-mgmt = {
            type = Service
            identifiers = ["ec2.amazonaws.com"]
            policies = ["aws:policy/AWSCodeCommitFullAccess"]
            instance_role = true
            force_detach_policies = true
        }
        eks = {
            type = Service
            identifiers = ["eks.amazonaws.com"]
            policies = ["aws:policy/AmazonEKSClusterPolicy", "aws:policy/AmazonEKSVPCResourceController"]
            force_detach_policies = true
        }
        eksnode = {
            type = Service
            identifiers = ["ec2.amazonaws.com"]
            policies = [
                "aws:policy/AmazonEKSWorkerNodePolicy", "aws:policy/AmazonEKS_CNI_Policy", 
                "aws:policy/AmazonEC2ContainerRegistryReadOnly", "aws:policy/AmazonS3FullAccess", 
                "aws:policy/AmazonSQSFullAccess", "aws:policy/AmazonCognitoPowerUser", 
                "aws:policy/AWSCodeCommitPowerUser", "aws:policy/CloudWatchFullAccess",
                "aws:policy/AmazonSNSFullAccess", "aws:policy/AmazonSESFullAccess", 
                "aws:policy/AWSCloudHSMFullAccess"
            ]
            force_detach_policies = true
        }
        rdsmon = {
            type = Service
            identifiers = ["monitoring.rds.amazonaws.com"]
            policies = ["aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]
            force_detach_policies = true
        }
        flogs = {
            type = Service
            identifiers = ["vpc-flow-logs.amazonaws.com"]
            policies = ["aws:policy/p_logs_prod_kr"]
            force_detach_policies = true
        }
        apigwlogs = {
            type = Service
            identifiers = ["apigateway.amazonaws.com"]
            policies = ["aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"]
            force_detach_policies = true
        }
    }
    */
}

variable "groups" {
    description = "IAM groups"
    type = map(list(string))
    default = {}
    /* Sample configuration
    default = {
        admin = ["aws:policy/AdministratorAccess"]
        dba = ["aws:policy/AmazonRDSFullAccess", "aws:policy/ReadOnlyAccess", "aws:policy/AmazonElastiCacheFullAccess"]
        users = ["aws:policy/ReadOnlyAccess"]
    }
    */
}

variable "users" {
    description = "IAM users"
    type = any
    default = {}
    /*
    type = map(object({
       groups = list(string)
       policies = list(string)
       console_login = bool
       programmtic_access = bool
    }))
    */
    /* Sample configuration
    default = {
        "sample.user@email.com" = {
            groups = ["admin"]
            policies = ["${local.account_id}:policy/ForceIpRestriction", "${local.account_id}:policy/ForceMFARestriction"]
            console_login = true
            programmatic_access = true
            force_destroy = true
        }
    }
    */
}

variable "encrypt_gpg" {
    description = "gpg public key to encrypt IAM user password or secret key"
    type = string
    default = null
}

variable "use_default_password_policy" {
    description = "Use default Strict password policy"
    type = bool
    default = true
}
