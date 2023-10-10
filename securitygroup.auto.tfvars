sg_rules = {
    bastion = {
        type = "se"
        description = "bastion server security group"
        ingresses = [
            {
                from = 9100
                to = 9100
                proto = "tcp"
                sg_name = "eks"
                description = "monitoring_Prometheus"
            }
        ]
        egresses = [
			{
                from = 2022
                to = 2022
                proto = "tcp"
                sg_name = "admin"
                description = "admin_SSH"
            }
        ]
    },
    admin = {
        type = "se"
        description = "admin server security group"
        ingresses = [
            {
                from = 2022
                to = 2022
                proto = "tcp"
                sg_name = "bastion"
                description = "bastion_SSH"
            },
            {
                from = 9100
                to = 9100
                proto = "tcp"
                sg_name = "eks"
                description = "monitoring_Prometheus"
            }
        ]
        egresses = [
			{
                from = 5306
                to = 5306
                proto = "tcp"
                sg_name = "rds"
                description = "RDS_MySQL"
            },
            {
                from = 8379
                to = 8379
                proto = "tcp"
                sg_name = "redis"
                description = "ElastiCache_Redis"
            },
            {
                from = 443
                to = 443
                proto = "tcp"
                sg_name = "eks"
                description = "EKS_APIServer"
            },
            {
                from = 22
                to = 22
                proto = "tcp"
                sg_name = "eks"
                description = "EKSNode_SSH"
            }
        ]
    },
    common = {
        type = "se"
        description = "common security group"
        ingresses = []
        egresses = [
            {
                from = 443
                to = 443
                proto = "tcp"
                cidrs = ["0.0.0.0/0"]
                description = "Anyopen_HTTPS"
            }
        ]
    },
    rds = {
        type = "sr"
        description = "RDS security group"
        ingresses = [
            {
                from = 5306
                to = 5306
                proto = "tcp"
                sg_name = "admin"
                description = "Admin_MySQL"
            },
            {
                from = 5306
                to = 5306
                proto = "tcp"
                sg_name = "eks"
                description = "EKSNode_MySQL"                    
            }
		]
        egresses = []
    },
    redis = {
        type = "sc"
        description = "ElastiCache security group"
        ingresses = [
            {
                from = 8379
                to = 8379
                proto = "tcp"
                sg_name = "admin"
                description = "Admin_Redis"
            },
            {
                from = 8379
                to = 8379
                proto = "tcp"
                sg_name = "eks"
                description = "EKSNode_Redis"                    
            }
		]
        egresses = []
    },
    eks = {
        type = "sk"
        description = "EKS security group"
        ingresses = [
            {
                from = 22
                to = 22
                proto = "tcp"
                sg_name = "admin"
                description = "Admin_SSH"
            },
            {
                from = 443
                to = 443
                proto = "tcp"
                sg_name = "admin"
                description = "Admin_APIServer"
            }
		]
        egresses = [
            {
                from = 5306
                to = 5306
                proto = "tcp"
                sg_name = "rds"
                description = "RDS_MySQL"
            },
            {
                from = 8379
                to = 8379
                proto = "tcp"
                sg_name = "redis"
                description = "ElastiCache_Redis"
            },
            {
                from = 27017
                to = 27017
                proto = "tcp"
                sg_name = "docdb"
                description = "DocumentDB"
            },
            {
                from = 443
                to = 443
                proto = "tcp"
                cidrs = ["10.1.0.0/16"]
                description = "AWS-VPCEndpoints_HTTPS"
            },
            {
                from = 443
                to = 443
                proto = "tcp"
                cidrs = ["0.0.0.0/0"]
                description = "EKS-cluster_HTTPS"
            },
            {
                from = 9100
                to = 9100
                proto = "tcp"
                sg_name = "bastion"
                description = "node_exporter_bastion"
            },
            {
                from = 9100
                to = 9100
                proto = "tcp"
                sg_name = "admin"
                description = "node_exporter_admin"
            }
		]
    },
    endpoints = {
        type = "sp"
        description = "VPC interface endpoints security group"
        ingresses = [
            {
                from = 443
                to = 443
                proto = "tcp"
                cidrs = ["10.1.0.0/16"]
                description = "VPC-subnet_HTTPS"
            }
        ]
        egresses = [
            {
                from = 0
                to = 0
                proto = "-1"
                cidrs = ["0.0.0.0/0"]
                description = "VPC-subnet_ALL"
            }
        ]
    },
    docdb = {
        type = "sr"
        description = "DocumentDB security group"
        ingresses = [
            {
                from = 27017
                to = 27017
                proto = "tcp"
                sg_name = "eks"
                description = "EKSNode_DocumentDB"
            }
		]
        egresses = []
    }
}