/*  Management EC2 (bastion, deploy)
    Naming rule
        EIP: eip_natgw_[service name]_[purpose]_[env]_[region] ex) eip_hub_dks_svc_prod_kr
        EBS: vol_[ec2]_[dev]_[service name]_[purpose]_[env]_[az]_[region] ex) vol_hub_sda_dks_svc_prod_a_kr
        EC2: [host_name]_[module]_[service name]_[purpose]_[env]_[az]_[region] ex) hub_mgt_dks_svc_prod_a_kr
        AMI: ami_[dev]_[ec2 name] ex) ami_sda_bastion_mgt_dks_svc_prod_kr
        Snapshot: snap_[dev]_[ec2 name] ex) snap_sda_bastion_mgt_dks_svc_prod_kr
        AutoScaleGroup: asg_[name]_[service name]_[purpose]_[env]_[region] ex) asg_web_dks_svc_prod_kr
*/
# Bastion server installation
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}

locals {
    svc_name = lower(var.svc_name)
    purpose = lower(var.purpose)
    env = lower(var.env)
    region_name_alias = lower(var.region_name_alias)
    suffix = "${local.svc_name}_${local.purpose}_${local.env}_${local.region_name_alias}"
    
    instances = merge( { for k, v in var.instances : k => v if try(v.count, 1) < 2 }, 
                        merge( [ for k, v in var.instances : 
                                { for idx in range(1, try(v.count, 1)+1) : "${k}-${tostring(idx)}" => v if try(v.count, 1) > 1 } ]...)
                     )
}

resource "aws_eip" "ec2" {
    for_each = { for k, v in local.instances : k => v if v.elastic_ip_address }
    
    instance = aws_instance.ec2[each.key].id
    vpc = true
    
    tags = {
        # Naming rule: eip_[purpose]_[service name]_[purpose]_[env]_[region] ex) eip_bastion_dks_svc_prod_kr
        Name = "eip_${each.key}_${local.suffix}"
    }
    
    depends_on = [aws_instance.ec2]
}

resource "aws_instance" "ec2" {
    for_each = local.instances
    ami = each.value.ami_id
    instance_type = each.value.type
    associate_public_ip_address = lookup(each.value, "associate_public_ip_address", true)

    availability_zone = each.value.availability_zone
    subnet_id = each.value.subnet_id
    private_ip = lookup(each.value, "private_ip", null)

    key_name = lookup(each.value, "key_name", null)
    iam_instance_profile = lookup(each.value, "role", null)
    user_data = lookup(each.value, "user_data", null)
    
    monitoring = lookup(each.value, "detailed_monitoring", false)
    vpc_security_group_ids = each.value.security_group_ids

    root_block_device {
        volume_size = each.value.root_block_device.volume_size
        volume_type = each.value.root_block_device.volume_type
        encrypted = lookup(each.value.root_block_device, "encrypted", true)
        delete_on_termination = lookup(each.value.root_block_device, "delete_on_termination", true)
        tags = merge(
            lookup(each.value, "tags", null),
            {
                # Naming rule: vol_[ec2]_[dev]_[service name]_[purpose]_[env]_[az]_[region] ex) vol_hub_sda_dks_svc_prod_a_kr
                Name = "vol_${each.key}_sda_${local.svc_name}_${local.purpose}_${local.env}_${substr(each.value.availability_zone,-1,-1)}_${local.region_name_alias}"
            }
        )
    }
    dynamic "ebs_block_device" {
        for_each = lookup(each.value, "ebs_block_device", null) != null ? each.value.ebs_block_device : []
        content {
            device_name = ebs_block_device.value.device_name
            volume_size = ebs_block_device.value.volume_size
            volume_type = ebs_block_device.value.volume_type
            encrypted = lookup(ebs_block_device.value, "encrypted", true)
            delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", true)
            tags = merge(
                lookup(each.value, "tags", null),
                {
                    # Naming rule: vol_[ec2]_[dev]_[service name]_[purpose]_[env]_[az]_[region] ex) vol_hub_sda_dks_svc_prod_a_kr
                    Name = "vol_${each.key}_${reverse(split("/",ebs_block_device.value.device_name))[0]}_${local.svc_name}_${local.purpose}_${local.env}_${substr(each.value.availability_zone,-1,-1)}_${local.region_name_alias}"
                }
            )
        }
    }
    tags = merge(
        lookup(each.value, "tags", null),
        {
            # Naming rule: [host_name]_[module]_[service name]_[purpose]_[env]_[az]_[region] ex) hub_mgt_dks_svc_prod_a_kr
            Name = "${each.key}_${each.value.module}_${local.svc_name}_${local.purpose}_${local.env}_${substr(each.value.availability_zone,-1,-1)}_${local.region_name_alias}" 
        }
    )
    lifecycle {
        ignore_changes = [user_data]
    }
}

# 2021.1 Security Recommendation
resource "aws_ec2_serial_console_access" "main" {
    enabled = var.enable_serial_console_access
}