data "aws_caller_identity" "current" {}

locals {
    account_id = data.aws_caller_identity.current.account_id
    suffix = "${lower(var.svc_name)}_${lower(var.purpose)}_${lower(var.env)}_${lower(var.region_name_alias)}"
}

################################################### 1. NETWORK ################################################### {
module "vpc" {
    source = "./modules/network/vpc"
    region_name = var.region_name
    svc_name = var.svc_name
    purpose = var.purpose
    env = var.env
    region_name_alias = var.region_name_alias
    az_names = var.az_names
    cidr_block = var.vpc_cidr_block
    public_cidrs = var.public_cidrs
    privnat_cidrs = var.privnat_cidrs
    private_cidrs = var.private_cidrs
}
module "sg" {
    source = "./modules/security/securitygroup"
    # should use count variable to use "*""
    vpc_id = module.vpc.vpc_id
    svc_name = var.svc_name
    purpose = var.purpose
    env = var.env
    region_name_alias = var.region_name_alias
    sg_rules = var.sg_rules
}
#### bastion ingress inbound rule with myip ####
data "http" "myip" {
  url = "https://ipv4.icanhazip.com"
}
resource "aws_security_group_rule" "bastion_inbound_rule" {
    type = "ingress"
    from_port = var.ssh_port
    to_port = var.ssh_port
    protocol = "tcp"
    #cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
    cidr_blocks = var.my_home_ip
    security_group_id = module.sg.sg_id_map["bastion"]
    description = "My_Home"
}
######################################
module "vpc_endpoints" {
    source = "./modules/network/endpoints"
    vpc_id = module.vpc.vpc_id
    region_name = var.region_name
    svc_name = var.svc_name
    purpose = var.purpose
    env = var.env
    region_name_alias = var.region_name_alias
    gateway_endpoints = {
        s3 =  {
            rt_ids = concat(module.vpc.public_rt_ids, module.vpc.privnat_rt_ids)
        }
    }
    interface_endpoints = {
        sns = {
            subnet_ids = module.vpc.privnat_subnet_ids
            security_groups = [module.sg.sg_id_map["endpoints"]]
        }
        logs = { # AWS cloudwatch logs vpc endpoint
            subnet_ids = module.vpc.privnat_subnet_ids
            security_groups = [module.sg.sg_id_map["endpoints"]]
        }
        autoscaling = { # AWS autoscaling vpc endpoint AWS Console <----> EKS autoscaler controller
            subnet_ids = module.vpc.privnat_subnet_ids
            security_groups = [module.sg.sg_id_map["endpoints"]]
        }
        elasticloadbalancing = { # ELB vpc endpoint
            subnet_ids = module.vpc.privnat_subnet_ids
            security_groups = [module.sg.sg_id_map["endpoints"]]
        }
    }
}
resource "aws_eip" "eip_NLB" {
    count = 2
    vpc  = true
    tags = {
      Name = "NLB-terraform-EIP-${count.index}"
    }
}
################################################### 1. NETWORK ################################################### }

################################################### 2. COMPUTE ################################################### {
resource "aws_key_pair" "ec2_ssh" {
# key enrollment to AWS
# ssh-keygen -t rsa -b 4096 -m PEM -f ".sec/ec2_emarket_dev_us" -N "" -C "t3-cta"    
# keyname => kp_ec2_emarket_dev_us
    key_name = "kp_ec2_${local.suffix}"
    public_key = file("${path.module}/.sec/ec2_emarket_dev_us.pub")
    tags = {
        # Naming rule: 
        Name = "kp_ec2_${local.suffix}"
    }
}
data "template_file" "iam_policies" {
    for_each = { for k in fileset("${path.module}/iam_policies", "*.json") : split(".", k)[0] => "${path.module}/iam_policies/${k}" }
    template = file(each.value)
    vars = {}
}
module "iam" {
    source = "./modules/identity/iam"
    env = var.env
    region_name_alias = var.region_name_alias
    policies = { for k, v in data.template_file.iam_policies : k => v.rendered }
    roles = {
        eks = { # eks cluster role
            type = "Service"
            identifiers = ["eks.amazonaws.com"]
            policies = ["AmazonEKSClusterPolicy", "AmazonEKSVPCResourceController"]
        }
        eksnode = { # eks node group role
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
            policies = [
                "AmazonEKSWorkerNodePolicy", "AmazonEKS_CNI_Policy", "AmazonEC2ContainerRegistryReadOnly",
                "AmazonS3FullAccess", "CloudWatchFullAccess", "AmazonDocDBFullAccess",
                "AmazonEBSCSIDriverPolicy", "eks-autoscale", "eks-ingressctrl", "eks-externaldns"
            ]
        }
        flogs = { # vpc flow logs role
            type = "Service"
            identifiers = ["vpc-flow-logs.amazonaws.com"]
            policies = ["logs"]
        }
        backup = { # aws backup role
            type = "Service"
            identifiers = ["backup.amazonaws.com"]
            policies = [
                 "AWSBackupServiceRolePolicyForBackup", "AWSBackupServiceRolePolicyForRestores", 
                 "AmazonSNSFullAccess", "backup-tag"
            ]
        }
    }
}
module "eks" {
    source = "./modules/compute/eks"
    vpc_id = module.vpc.vpc_id
    svc_name = var.svc_name
    purpose = var.purpose
    env = var.env
    region_name_alias = var.region_name_alias
    ## cluster configuration
    cluster_name = "cluster"
    cluster_version = "1.24"
    cluster_role_arn = module.iam.role_arn_map["eks"]
    ingress_subnet_ids = module.vpc.public_subnet_ids
    nodegrp_subnet_ids = module.vpc.privnat_subnet_ids
    nodegrp_role_arn = module.iam.role_arn_map["eksnode"]
    enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
    log_retention_in_days = 14
    security_group_ids = [module.sg.sg_id_map["eks"]] # cluster Additional Security group ID
    endpoint_private_access = true
    endpoint_public_access = true
    public_access_cidrs = ["${chomp(data.http.myip.response_body)}/32"]   ## GitOps Console's CIDR
    use_container_insights = false
    ## worker nodes configuration
    eks_node_groups = {
        worker = {
            ami_type = "AL2_x86_64" # AL2_x86_64 | AL2_x86_64_GPU | AL2_ARM_64 | CUSTOM | BOTTLEROCKET_ARM_64 | BOTTLEROCKET_x86_64
            capacity_type = "ON_DEMAND" # ON_DEMAND | SPOT
            instance_types = ["t3.xlarge"] 
            scaling_config = { max_size = 5, min_size = 3, desired_size = 3 }
            update_config = { max_unavailable_percentage = 25 }
            # for launch template
            key_name = aws_key_pair.ec2_ssh.key_name
            vpc_security_group_ids = [module.sg.sg_id_map["eks"]]
            tag_specifications = {
                instance = { Name: "worker_eks_${local.suffix}" }
                volume = { Name: "vol_worker_eks_sda_${local.suffix}" }
                network-interface = { Name: "eth_worker_eks_${local.suffix}" }
            }
        }
    }
    ## add ons
    add_ons = [
        { name = "vpc-cni" },
        { name = "kube-proxy" },
        { name = "coredns" },
        { name = "aws-ebs-csi-driver" }
    ]
}
# Auto Scaling policy (CPU Utilization Policy)
resource "aws_autoscaling_policy" "as_policy" {
    for_each = module.eks.asg_name_map

    autoscaling_group_name = each.value
    name                   = "Average CPU utilization Tracking Policy"
    policy_type            = "TargetTrackingScaling"
    target_tracking_configuration {
        predefined_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = var.autoscaling_policy_target_value
    }
}
module "ec2" {
    source = "./modules/compute/ec2"
    vpc_id = module.vpc.vpc_id
    svc_name = var.svc_name
    purpose = var.purpose
    env = var.env
    region_name_alias = var.region_name_alias
    instances = {
        bastion = {
            module = "mgmt"
            ami_id = var.ami_id #ubuntu 22.04 LTS
            type = "t2.micro"
            elastic_ip_address = true
            availability_zone = var.az_names[0]
            subnet_id = module.vpc.public_subnet_az_map[var.az_names[0]]
            key_name = aws_key_pair.ec2_ssh.key_name

            user_data = templatefile("${path.module}/init_scripts/cloud_init.sh",
                {
                    HOSTNAME = "bastion.mgmt.emarket.svc.dev.a.us"
                    SSHD_PORT = var.ssh_port
                    KUBECONFIG = module.eks.kubeconfig
                 })
            root_block_device = {
                volume_size = "8"
                volume_type = "gp2"
                encrypted = true
                delete_on_termination = true
            }
            security_group_ids = [module.sg.sg_id_map["bastion"], module.sg.sg_id_map["common"]]
            tags = {
                RES_Class_0 = "MGMT"
                RES_Class_1 = "BASTION"
                RES_Class_2 = "US"
                prometheus_monitoring = "true"
            }
        }
        admin = {
            module = "mgmt"
            ami_id = var.ami_id #ubuntu 22.04 LTS
            type = "t2.micro"
            elastic_ip_address = false
            associate_public_ip_address = false
            availability_zone = var.az_names[0]
            subnet_id = module.vpc.privnat_subnet_az_map[var.az_names[0]]
            key_name = aws_key_pair.ec2_ssh.key_name

            user_data = templatefile("${path.module}/init_scripts/cloud_init.sh",
                {
                    HOSTNAME = "admin.mgmt.emarket.svc.dev.a.us"
                    SSHD_PORT = var.ssh_port
                    KUBECONFIG = module.eks.kubeconfig
                 })
            root_block_device = {
                volume_size = "10"
                volume_type = "gp2"
                encrypted = true
                delete_on_termination = true
            }
            security_group_ids = [module.sg.sg_id_map["admin"], module.sg.sg_id_map["common"]]
            tags = {
                RES_Class_0 = "MGMT"
                RES_Class_1 = "ADMIN"
                RES_Class_2 = "US"
                prometheus_monitoring = "true"
            }
        }
    }
}
# Resource group
resource "aws_resourcegroups_group" "ec2_resource_group" {
   name = "rg-mgmt"
   resource_query {
       query = <<JSON
       {
           "ResourceTypeFilters": [
               "AWS::EC2::Instance"
           ],
           "TagFilters": [
               {
                   "Key": "RES_Class_0",
                   "Values": ["MGMT"]
               }
           ]
       }
    JSON
    }
}
################################################### 2. COMPUTE ################################################### }

################################################### 3. DATABASE ################################################### {
resource "random_string" "password" {
  length  = 10
  special = false
}
module "rds" {
    source = "./modules/database/rds"
    svc_name = var.svc_name
    purpose = var.purpose
    env = var.env
    region_name_alias = var.region_name_alias
    
    engine = "mariadb"
    engine_version = "10.5.19"
    auto_minor_version_upgrade = false
    instance_class = "db.t3.medium"
    identifier = "cta"
    # Availability and Backup & Restore
    multi_az = true
    backup_retention_period = 1
    delete_automated_backups = true

    subnet_ids = module.vpc.private_subnet_ids
    port = 5306
    
    allocated_storage = 10
    max_allocated_storage = 15
    db_name = "KeycloakDb"
    username = var.db_username
    password = random_string.password.result
    
    storage_type = "gp2"
    apply_immediately = true
    storage_encrypted = true
    ca_cert_identifier = "rds-ca-rsa2048-g1"
    security_group_ids = [module.sg.sg_id_map["rds"]]
    parameter_group = { 
        family = "mariadb10.5"
        parameters = [
            { 
                key = "max_connections"
                value = "1000" 
            }
        ]
    }
    tags = {
        RES_Class_0 = "EDU"
        RES_Class_1 = "DB"
        RES_Class_2 = "US"
    }
}
module "redis" {
    # NON cluster mode redis (replication group)
    source = "./modules/database/redis"
    svc_name = var.svc_name
    purpose = var.purpose
    env = var.env
    region_name_alias = var.region_name_alias
    az_names = var.az_names
    replication_group_id = "session"
    node_type = "cache.t3.micro" # Need change to "cache.m6g.large" in Disaster Recovery Class 
    num_cache_cluster = 2
    engine_version = "6.x"
    port = 8379
    parameter_group = "redis6.x"
    subnet_ids = module.vpc.private_subnet_ids
    security_group_ids = [module.sg.sg_id_map["redis"]]
    # Backup & Restore
    snapshot_retention_limit = 1
    tags = {
        RES_Class_0 = "EDU"
        RES_Class_1 = "Cache"
        RES_Class_2 = "US"
    }
}
################################################### 3. DATABASE ################################################### }

## The code below will be used in Disaster Recovery class. Don't delete below comments before Day 10.
/*
####################################### 4. DISATER RECOVERY - Service Region ####################################### {
resource "aws_docdb_cluster_parameter_group" "emarket_docdb_param" {
    family      = "docdb4.0"
    name        = "emarket-docdb-param"
    description = "docdb cluster parameter group"

    parameter {
        name  = "tls"
        value = "disabled"
    }
}

resource "aws_docdb_cluster_instance" "cluster_instances" {
    count              = 2
    identifier         = "docdb-emarket-${count.index}"
    cluster_identifier = aws_docdb_cluster.emarket_docdb_cluster.id
    instance_class     = "db.r6g.large"
    apply_immediately  = true 
}

resource "aws_docdb_cluster" "emarket_docdb_cluster" {
    engine_version = "4.0.0"
    cluster_identifier = "docdb-emarket"
    master_username    = var.doc_db_username
    master_password    = random_string.password.result

    db_subnet_group_name = element(split(":", module.rds.subnet_group_arn), length(split(":", module.rds.subnet_group_arn))-1)
    db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.emarket_docdb_param.name
    vpc_security_group_ids = [module.sg.sg_id_map["docdb"]]
    skip_final_snapshot = true
    deletion_protection = false
}
####################################### 4. DISATER RECOVERY - Service Region ####################################### }

######################################### 5. DISATER RECOVERY - DR Region ######################################### {
# mariadb parameter group in DR Region
resource "aws_db_parameter_group" "rds_pg_dr" {
    name = "pg-db-mariadb105-cta-emarket-dr-dev-us"
    family = "mariadb10.5"

    parameter {
        name = "max_connections"
        value = "1000" 
    }
}
# mariadb subnet group in DR Region
resource "aws_db_subnet_group" "rds_sg_dr" {
    name = "sg-mariadb-cta-emarket-dr-dev-us"
    subnet_ids = module.vpc.private_subnet_ids

    tags = {
        Name = "sg_mariadb_cta_emarket_dr_dev_us"
    }
}
# redis subnet group in DR Region
resource "aws_elasticache_subnet_group" "redis_sg_dr" {
    name = "sg-redis-cta-emarket-dr-dev-us"
    subnet_ids = module.vpc.private_subnet_ids

    tags = {
        Name = "sg_redis_cta_emarket_dr_dev_us"
    }
}
# documentdb parameter group in DR Region
resource "aws_docdb_cluster_parameter_group" "emarket_docdb_param_dr" {
    family      = "docdb4.0"
    name        = "emarket-docdb-param-dr"
    description = "docdb cluster parameter group"

    parameter {
        name  = "tls"
        value = "disabled"
    }
}
######################################### 5. DISATER RECOVERY - DR Region ######################################### }
*/
