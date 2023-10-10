variable "region_name" {
    description = "AWS VPC region name"
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

variable "az_names" {
    description = "AWS subnet region name list"
    type = list(string)
}

variable "cidr_block" {
    description = "VPC CIDR Address block"
    type = string
    default = "10.0.0.0/16"
}

variable "public_cidrs" {
    description = "AWS public subnet cidrs"
    type = list(object({
        availability_zone = string
        cidr_block = string
    }))
    /* Sample configuration
    default = [
        {
            availability_zone = "ap-northeast-2a"
            cidr_block = "10.0.0.0/24"
        },
        {
            availability_zone = "ap-northeast-2c"
            cidr_block = "10.0.0.1/24"
        }
    ]
    */
}

variable "privnat_cidrs" {
    description = "AWS private nat subnet cidrs"
    type = list(object({
        availability_zone = string
        cidr_block = string
    }))
    /* Sample configuration
    default = [
        {
            availability_zone = "ap-northeast-2a"
            cidr_block = "10.0.0.2/24"
        },
        {
            availability_zone = "ap-northeast-2c"
            cidr_block = "10.0.0.3/24"
        }
    ]
    */
}

variable "private_cidrs" {
    description = "AWS private subnet cidrs"
    type = list(object({
        availability_zone = string
        cidr_block = string
    }))
    /* Sample configuration
    default = [
        {
            availability_zone = "ap-northeast-2a"
            cidr_block = "10.0.0.4/24"
        },
        {
            availability_zone = "ap-northeast-2c"
            cidr_block = "10.0.0.5/24"
        }
    ]
    */
}

variable nacl_policy {
    description = "VPC NACL Policy"
    type = map(object({
        ingresses = list(object({
            protocol = number
            rule_no = number
            action = string
            cidr_block = string
            from_port = number
            to_port = number
        }))
        egresses = list(object({
            protocol = number
            rule_no = number
            action = string
            cidr_block = string
            from_port = number
            to_port = number           
        }))
    }))
    default = {
        public = {
            ingresses = [
                {
                    protocol = -1
                    rule_no = 100
                    action = "allow"
                    cidr_block = "0.0.0.0/0"
                    from_port = 0
                    to_port = 0
                }
            ]
            egresses = [
                {
                    protocol = -1
                    rule_no = 100
                    action = "allow"
                    cidr_block = "0.0.0.0/0"
                    from_port = 0
                    to_port = 0
                }
            ]
        },
        privnat = {
            ingresses = [
                {
                    protocol = -1
                    rule_no = 100
                    action = "allow"
                    cidr_block = "0.0.0.0/0"
                    from_port = 0
                    to_port = 0
                }
            ]
            egresses = [
                {
                    protocol = -1
                    rule_no = 100
                    action = "allow"
                    cidr_block = "0.0.0.0/0"
                    from_port = 0
                    to_port = 0
                }
            ]
        },
        private = {
            ingresses = [
                {
                    protocol = -1
                    rule_no = 100
                    action = "allow"
                    cidr_block = "0.0.0.0/0"
                    from_port = 0
                    to_port = 0
                }
            ]
            egresses = [
                {
                    protocol = -1
                    rule_no = 100
                    action = "allow"
                    cidr_block = "0.0.0.0/0"
                    from_port = 0
                    to_port = 0
                }
            ]
        }
    }
}