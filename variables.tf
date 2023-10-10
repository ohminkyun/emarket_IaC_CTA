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

variable "region_name" {
    description = "AWS VPC region name"
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

variable "vpc_cidr_block" {
    description = "VPC CIDR Address block"
    type = string
}

variable "public_cidrs" {
    description = "AWS public subnet cidrs"
    type = list(object({
        availability_zone = string
        cidr_block = string
    }))
}

variable "privnat_cidrs" {
    description = "AWS private nat subnet cidrs"
    type = list(object({
        availability_zone = string
        cidr_block = string
    }))
}

variable "private_cidrs" {
    description = "AWS private subnet cidrs"
    type = list(object({
        availability_zone = string
        cidr_block = string
    }))
}

variable "common_tags" {
    description = "default tags"
    type = map(string)
    default = {}
}

variable "sg_rules" {
    description = "Security group policy definition (source security group id)"
    type = any
}

variable "ssh_port" {
    description = "ssh port of bastion/admin instances"
    type = number
}

variable "ami_id" {
    description = "ami id"
    type = string
}

variable "db_username" {
    description = "MariaDB Database master username"
    type = string
    sensitive = true
}

variable "doc_db_username" {
    description = "DocumentDB Database master username"
    type = string
    sensitive = true
}

variable "autoscaling_policy_target_value" {
    description = "target value of autoscaling group policy"
    type = number
}

variable "my_home_ip" {
    description = "ip address of my home pc"
    type = list(string)
}