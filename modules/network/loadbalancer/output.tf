output "elb_arn_map" {
    description = "The ARN of the load balancer"
    value = { for k, v in aws_lb.main: k => v.arn }
}

output "elb_id_map" {
    description = "The ID of the load balancer"
    value = { for k, v in aws_lb.main: k => v.id }
}

output "elb_name_map" {
    description = "The Name of the load balancer"
    value = { for k, v in aws_lb.main: k => v.name }
}

output "elb_dns_name_map" {
    description = "The DNS name of the load balancer"
    value = { for k, v in aws_lb.main: k => v.dns_name }
}

output "target_group_arn_map" {
    description = "ARN of the Target Group"
    value = { for k, v in aws_lb_target_group.main: k => v.arn }
}

output "target_group_id_map" {
    description = "ID of the Target Group"
    value = { for k, v in aws_lb_target_group.main: k => v.id }
}

output "target_group_name_map" {
    description = "Name of the Target Group"
    value = { for k, v in aws_lb_target_group.main: k => v.name }
}

output "nlb_eip_map" {
    description = "Elastic IP Address map for NLB created in this module"
    value = { for k, v in aws_eip.main: k => v.public_ip }
}

output "listener_arn_map" {
    description = "ARN map of listners"
    value = { for k, v in aws_lb_listener.main : k => v.arn }
}

output "listener_id_map" {
    description = "ID map of listners"
    value = { for k, v in aws_lb_listener.main : k => v.id }
}