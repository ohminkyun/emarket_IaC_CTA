output "ec2_eip_map" {
    description = "bastion server instance id"
    value = { for k, v in aws_eip.ec2 : k => v.public_ip }
}

output "ec2_id_map" {
    description = "deploy server instance id"
    value = { for k, v in aws_instance.ec2 : k => v.id }
}

output "enable_serial_console_access" {
    description = "serial console access is enabled for your AWS account in the current AWS region"
    value = aws_ec2_serial_console_access.main.enabled
}
    
#bastion public ip, admin private ip added
output "bastion_ip" {
    description = "EC2 Bastion Server Public IP"
    value = aws_eip.ec2["bastion"].public_ip
}

output "admin_ip" {
    description = "EC2 Admin Server Private IP"
    value = aws_instance.ec2["admin"].private_ip
}
