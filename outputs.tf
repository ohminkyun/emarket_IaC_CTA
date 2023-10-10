#
# Outputs
#
### EIP1,2 allocatin_id for NLB
output "eip_allocation_id" {
  description = "EIPs for NLB of istio"
  value       = format("%s,%s", aws_eip.eip_NLB[0].id, aws_eip.eip_NLB[1].id)
}

### bastion public ip, admin private ip added
output "bastion_server_public_ip" {
    description = "EC2 Bastion Server's Public IP"
    value = module.ec2.bastion_ip
}

output "admin_server_private_ip" {
    description = "EC2 Admin Server's Private IP"
    value = module.ec2.admin_ip
}

### RDS(Mariadb)
output "mariadb_endpoint" {
  description = "The connection endpoint"
  value       = element(split(":", module.rds.endpoint),0)
}

### Elasticache(Redis)
output "redis_cluster_endpoint" {
  description = "The elasticache_cluster connection endpoint url"
  value       = module.redis.primary_endpoint
}

### user password
output "db_user_password" {
  description = "The master password for the database"
  value       = random_string.password.result
}
/*
### DocumentDB(MongoDB)
output "docdb_endpoint" {
  description = "Endpoint of DocumentDB"
  value = aws_docdb_cluster.emarket_docdb_cluster.endpoint
}
*/