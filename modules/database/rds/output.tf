output "address" {
    description = "The hostname of the RDS instance"
    value = aws_db_instance.main.address
}

output "port" {
    description = "The database port"
    value = aws_db_instance.main.port
}

output "endpoint" {
    description = "The connection endpoint in address:port format"
    value = aws_db_instance.main.endpoint
}

output "id" {
    description = "The RDS instance ID"
    value = aws_db_instance.main.id
}

output "arn" {
    description = "The ARN of the RDS instance"
    value = aws_db_instance.main.arn
}

output "db_name" {
    description = "The database name"
    value = aws_db_instance.main.db_name
}

output "engine" {
    description = "The database engine"
    value = aws_db_instance.main.engine
}

output "engine_version_actual" {
    description = "The running version of the database"
    value = aws_db_instance.main.engine_version_actual
}

output "latest_restorable_time" {
    description = "The latest time, in UTC RFC3339 format, to which a database can be restored with point-in-time restore"
    value = aws_db_instance.main.latest_restorable_time
}

output "multi_az" {
    description = "If the RDS instance is multi AZ enabled"
    value = aws_db_instance.main.multi_az
}

output "status" {
    description = "The RDS instance status"
    value = aws_db_instance.main.status
}

output "username" {
    description = "The master username for the database"
    value = aws_db_instance.main.username
    sensitive = true
}

output "subnet_group_id" {
    description = "The db subnet group name"
    value = aws_db_subnet_group.default.id
}

output "subnet_group_arn" {
    description = "The db subnet group arn"
    value = aws_db_subnet_group.default.arn
}

output "option_group_id" {
    description = "The db option group name"
    value = try(var.option_group_name, null) == null ? aws_db_option_group.main["default"].id : var.option_group_name
}

output "option_group_arn" {
    description = "The db subnet group arn"
    value = try(var.option_group_name, null) == null ? aws_db_option_group.main["default"].arn : var.option_group_name
}

output "parameter_group_id" {
    description = "The db parameter group name"
    value = try(var.parameter_group, null) != null ? aws_db_parameter_group.main["default"].id : var.parameter_group_name
}

output "parameter_group_arn" {
    description = "The db parameter group arn"
    value = try(var.parameter_group, null) != null ? aws_db_parameter_group.main["default"].arn : var.parameter_group_name
}