output "vpc_id" {
    description = "Created vpc id"
    value = aws_vpc.main.id
}

output "vpc_arn" {
    description = "Created vpc arn"
    value = aws_vpc.main.arn
}

output "public_subnet_ids" {
    description = "public subnet id list"
    value = aws_subnet.public.*.id
}

output "privnat_subnet_ids" {
    description = "private nat subnet id list"
    value = aws_subnet.privnat.*.id
}

output "private_subnet_ids" {
    description = "private subnet id list"
    value = aws_subnet.private.*.id
}

output "public_subnet_az_map" {
    description = "public subnet id and az map"
    value = local.public_subnet_az_map
}

output "privnat_subnet_az_map" {
    description = "private nat subnet id and az map"
    value = local.privnat_subnet_az_map
}

output "private_subnet_az_map" {
    description = "private subnet id and az map"
    value = local.private_subnet_az_map
}

output "subnet_zone_map" {
    description = "subnet & zone map (ex public => [id1, id2])"
    value = local.subnet_zone_map
}

output "internetgw_id" {
    description = "internet gateway ids"
    value = aws_internet_gateway.main.id
}

output "natgw_ids" {
    description = "nat gateway ids"
    value = [ for k, v in aws_nat_gateway.main : v.id ]
}

output "natgw_az_map" {
    description = "natgw and eip map (az:id)"
    value = { for k, v in aws_nat_gateway.main : k => v.id }
}

output "natgw_ips" {
    description = "Nat gateway public ip addresses"
    value = [ for k, v in aws_eip.natgw : v.public_ip ]
}

output "public_rt_id_map" {
    description = "public route table id map (az : id)"
    value = { for k in var.az_names : k => aws_route_table.public.id }
}

output "privnat_rt_id_map" {
    description = "privnat route table id map (az : id)"
    value = { for k, v in aws_route_table.privnat : k => v.id }
}

output "private_rt_id_map" {
    description = "private route table id map (az : id)"
    value = { for k in var.az_names : k => aws_route_table.private.id }
}

output "public_rt_ids" {
    description = "public route table id list"
    value = [ aws_route_table.public.id ]
}

output "privnat_rt_ids" {
    description = "privnat route table id list"
    value = [ for k, v in aws_route_table.privnat : v.id ]
}

output "private_rt_ids" {
    description = "private route table id list"
    value = [ aws_route_table.private.id ]
}