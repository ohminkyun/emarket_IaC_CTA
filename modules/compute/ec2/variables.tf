variable "vpc_id" {
    description = "VPC id"
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

variable "instances" {
    description = "EC2 instance configuration"
    type = any
    /* key => instance name
    type = map(object({
        module = string
        count = number
        ami_id = string
        type = string
        elastic_ip_address = bool
        associate_public_ip_address = bool
        availability_zone = string
        subnet_id = string
        private_ip = string
        key_name = string
        role = string
        user_data = string
        detailed_monitoring = bool
        root_block_device = object({
            volume_size = string
            volume_type = string
            encrypted = bool
            delete_on_termination = bool
        })
        ebs_block_device = list(object({
            device_name = string
            volume_size = string
            volume_type = string
            encrypted = bool
            delete_on_termination = bool
        }))
        security_group_ids = list(string)
        tags = map(string)
    }))
    */
    default = {}
}

variable "enable_serial_console_access" {
    description = "serial console access is enabled for your AWS account in the current AWS region"
    type = bool
    default = false
}