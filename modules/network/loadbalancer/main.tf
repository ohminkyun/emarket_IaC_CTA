/*  Resource Naming rule
    ELB: alb[nlb]-[elb_name]-[in/out]-[service name]-[purpose]-[env]-[region] ex) alb-emm-km-svc-dev-kr
    Not Fully Tested module (2022.04.27)
*/
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
    suffix = "${local.svc_name}-${local.purpose}-${local.env}-${local.region_name_alias}"
}

resource "aws_lb_target_group" "main" {
    for_each = var.target_groups
    name = each.key
    target_type = try(each.value.target_type, "instance")
    vpc_id = try(each.value.target_type, "instance") != "lambda" ? each.value.vpc_id : null
    port = each.value.port
    protocol = each.value.protocol
    protocol_version = lookup(each.value, "protocol_version", null)
    proxy_protocol_v2 = lookup(each.value, "proxy_protocol_v2", false)
    preserve_client_ip = lookup(each.value, "preserve_client_ip", null)
    load_balancing_algorithm_type = lookup(each.value, "load_balancing_algorithm_type", null)

    dynamic "health_check" {
        for_each = try(each.value.health_check, null) != null ? [each.value.health_check] : []
        content {
            enabled = lookup(health_check.value, "enabled", true)
            healthy_threshold = lookup(health_check.value, "healthy_threshold", null) # default: 2
            matcher = lookup(health_check.value, "matcher", null)
            path = lookup(health_check.value, "path", null)
            port = lookup(health_check.value, "port", null)
            protocol = lookup(health_check.value, "protocol", null) # HTTP or HTTPS only
            timeout = lookup(health_check.value, "timeout", null) # default: 10
            unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", null) # default: 3
        }
    }
    slow_start = lookup(each.value, "slow_start", null)
    deregistration_delay = lookup(each.value, "deregistration_delay", 300)
    connection_termination = lookup(each.value, "connection_termination", false)
    
    dynamic "stickiness" {
        for_each = try(each.value.stickiness, null) != null ? [each.value.stickiness] : []
        content {
            enabled = lookup(stickiness.value, "enabled", true)
            type = stickiness.value.type
            cookie_duration = lookup(stickiness.value, "cookie_duration", 86400)
            cookie_name = lookup(stickiness.value, "cookie_name", null)
        }
    }
    lambda_multi_value_headers_enabled = lookup(each.value, "lambda_multi_value_headers_enabled", false)
    
    tags = merge({ Name = "tg_${each.key}_${replace(local.suffix, "-", "_")}" }, try(each.value.tags, {}))
}

resource "aws_lb_target_group_attachment" "main" {
    for_each =  merge([ for tg_name, tg_info in var.target_groups: 
                        { for target in try(tg_info.targets, []): "${tg_name}^${target.target_id}" => target }
                ]...)
    
    target_group_arn = aws_lb_target_group.main[split("^", each.key)[0]].arn
    target_id = each.value.target_id
    port = lookup(each.value, "port", null)
    availability_zone = lookup(each.value, "availability_zone", null)
    
    depends_on = [aws_lb_target_group.main]
}

# Elastic IP Address for Network LoadBalancer
resource "aws_eip" "main" {
    for_each =  merge([ for k, v in var.elbs:
                        { for subnet_info in try(v.subnet_mapping, []): "${k}^${subnet_info.subnet_id}" => subnet_info if subnet_info.create_eip }
                ]...)
    vpc = true
    tags = {
        Name = format("eip_nlb-${split("^",each.key)[0]}_%s_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, substr(lower(each.value.availability_zone), -1, -1), local.region_name_alias)
    }
}

resource "aws_lb" "main" {
    for_each = var.elbs
    name = "${substr(try(each.value.type, "application"),0,1)}lb-${each.key}-${local.suffix}"
    load_balancer_type = lookup(each.value, "type", "application")
    internal = lookup(each.value, "internal", false)
    security_groups = lookup(each.value, "security_groups", null)
    subnets = lookup(each.value, "subnets", null)
    dynamic "subnet_mapping" { # for NLB
        for_each = try(each.value.subnet_mapping, [])
        content {
            subnet_id = subnet_mapping.value.subnet_id
            allocation_id = try(subnet_mapping.value.create_eip, false) ? aws_eip.main["${each.key}^${subnet_mapping.value.subnet_id}"].allocation_id : lookup(subnet_mapping.value, "allocation_id", null)
            private_ipv4_address = lookup(subnet_mapping.value, "private_ipv4_address", null)
            ipv6_address = lookup(subnet_mapping.value, "ipv6_address", null)
        }
    }
    ip_address_type = lookup(each.value, "ip_address_type", null)
    drop_invalid_header_fields = lookup(each.value, "drop_invalid_header_fields", false)
    dynamic "access_logs" {
        for_each = try(each.value.access_logs, null) != null ? [each.value.access_logs] : []
        content {
            bucket = access_logs.value.bucket
            prefix = lookup(access_logs.value, "prefix", null)
            enabled = lookup(access_logs.value, "enabled", true)
        }
    }
    
    idle_timeout = lookup(each.value, "idle_timeout", 60)
    enable_deletion_protection = lookup(each.value, "enable_deletion_protection", false)
    enable_cross_zone_load_balancing = lookup(each.value, "enable_cross_zone_load_balancing", true) #for NLB
    enable_http2 = lookup(each.value, "enable_http2", true)
    enable_waf_fail_open = lookup(each.value, "enable_waf_fail_open", false)
    customer_owned_ipv4_pool = lookup(each.value, "customer_owned_ipv4_pool", null)
    desync_mitigation_mode = lookup(each.value, "desync_mitigation_mode", "defensive")
    
    
    tags = merge({Name = "${substr(try(each.value.type, "application"),0,1)}lb_${each.key}_${replace(local.suffix,"-","_")}"}, try(each.value.tags, {}))
}

resource "aws_lb_listener" "main" {
    for_each =  merge([ for k, v in var.elbs:
                     { for listener in try(v.listeners, []): "${k}^${listener.protocol}^${listener.port}" => listener }
                ]...)
    load_balancer_arn = aws_lb.main[split("^", each.key)[0]].arn
    port = lookup(each.value, "port", null)
    protocol = lookup(each.value, "protocol", null)
    ssl_policy = lookup(each.value, "ssl_policy", null)
    certificate_arn = lookup(each.value, "certificate_arn", null)
    alpn_policy = lookup(each.value, "alpn_policy", null)
    
    dynamic "default_action" {
        for_each = [each.value.default_action]
        content {
            type = default_action.value.type
            order = lookup(default_action.value, "order", null)
            target_group_arn = lookup(default_action.value, "target_group_name", null) != null ? aws_lb_target_group.main[default_action.value.target_group_name].arn : null
            
            dynamic "authenticate_cognito" {
                for_each = try(default_action.value.authenticate_cognito, null) != null ? [default_action.value.authenticate_cognito] : []
                content {
                    user_pool_arn = authenticate_cognito.value.user_pool_arn
                    user_pool_client_id = authenticate_cognito.value.user_pool_client_id
                    user_pool_domain = authenticate_cognito.value.user_pool_domain
                    on_unauthenticated_request = lookup(authenticate_cognito.value, "on_unauthenticated_request", null)
                    scope = lookup(authenticate_cognito.value, "scope", null)
                    session_cookie_name = lookup(authenticate_cognito.value, "session_cookie_name", null)
                    session_timeout = lookup(authenticate_cognito.value, "session_timeout", null)
                    authentication_request_extra_params = try(authenticate_cognito.value.authentication_request_extra_params, {})
                }
                
            }
            
            dynamic "authenticate_oidc" {
                for_each = try(default_action.value.authenticate_oidc, null) != null ? [default_action.value.authenticate_oidc] : []
                content {
                    authorization_endpoint = authenticate_oidc.value.authorization_endpoint
                    client_id = authenticate_oidc.value.client_id
                    client_secret = authenticate_oidc.value.client_secret
                    issuer = authenticate_oidc.value.issuer
                    token_endpoint = authenticate_oidc.value.token_endpoint
                    user_info_endpoint = authenticate_oidc.value.user_info_endpoint
                    on_unauthenticated_request = lookup(authenticate_oidc.value, "on_unauthenticated_request", null)
                    scope = lookup(authenticate_oidc.value, "scope", null)
                    session_cookie_name = lookup(authenticate_oidc.value, "session_cookie_name", null)
                    session_timeout = lookup(authenticate_oidc.value, "session_timeout", null)
                    authentication_request_extra_params = try(authenticate_oidc.value.authentication_request_extra_params, {})
                }
            }
            
            dynamic "fixed_response" {
                for_each = try(default_action.value.fixed_response, null) != null ? [default_action.value.fixed_response] : []
                content {
                    content_type = fixed_response.value.content_type
                    message_body = lookup(fixed_response.value, "message_body", null)
                    status_code = lookup(fixed_response.value, "status_code", null)
                }
            }
            
            dynamic "forward" {
                for_each = try(default_action.value.weighted_forward, null) != null ? [default_action.value.weighted_forward] : []
                content {
                    dynamic "target_group" {
                        for_each = forward.value.target_groups
                        content {
                            arn = aws_lb_target_group.main[target_group.value.name].arn
                            weight = lookup(target_group.value, "weight", null)
                        }
                    }
                    dynamic "stickiness" {
                        for_each = try(forward.value.stickiness, null) != null ? [forward.value.stickiness] : []
                        content {
                            duration = stickiness.value.duration
                            enabled = lookup(stickiness.value, "enabled", false)
                        }
                    }
                }
            }
            
            dynamic "redirect" {
                for_each = try(default_action.value.redirect, null) != null ? [default_action.value.redirect] : []
                content {
                    status_code = redirect.value.status_code
                    host = lookup(redirect.value, "host", null)
                    path = lookup(redirect.value, "path", null)
                    port = lookup(redirect.value, "port", null)
                    protocol = lookup(redirect.value, "protocol", null)
                    query = lookup(redirect.value, "query", null)
                }
            }
        }
    }
    
    depends_on = [aws_lb.main, aws_lb_target_group.main]
}

resource "aws_lb_listener_certificate" "main" {
    for_each = merge(flatten([ for k, v in var.elbs:
                     [ for listener in try(v.listeners, []): 
                     { for certificate in try(listener.additional_certificate_arns, []): "${k}^${listener.protocol}^${listener.port}^${reverse(split("/", certificate))[0]}" => certificate }
                ]])...)
                
    listener_arn = aws_lb_listener.main[trimsuffix(each.key, "^${reverse(split("/", each.value))[0]}")].arn
    certificate_arn = each.value

    depends_on = [aws_lb_listener.main]
}

resource "aws_lb_listener_rule" "main" {
    for_each =  merge(flatten([ for k, v in var.elbs:
                      [ for listener in try(v.listeners, []):
                      { for rule in try(listener.rules, []) : "${k}^${listener.protocol}^${listener.port}^${rule.priority}" => rule }
                ]])...)
    
    listener_arn = aws_lb_listener.main[trimsuffix(each.key, "^${each.value.priority}")].arn
    priority = each.value.priority
    
    dynamic "action" {
        for_each = try(each.value.actions, [])
        content {
            type = action.value.type
            target_group_arn = lookup(action.value, "target_group_name", null) != null ? aws_lb_target_group.main[action.value.target_group_name].arn : null
            
            dynamic "authenticate_cognito" {
                for_each = try(action.value.authenticate_cognito, null) != null ? [action.value.authenticate_cognito] : []
                content {
                    user_pool_arn = authenticate_cognito.value.user_pool_arn
                    user_pool_client_id = authenticate_cognito.value.user_pool_client_id
                    user_pool_domain = authenticate_cognito.value.user_pool_domain
                    on_unauthenticated_request = lookup(authenticate_cognito.value, "on_unauthenticated_request", null)
                    scope = lookup(authenticate_cognito.value, "scope", null)
                    session_cookie_name = lookup(authenticate_cognito.value, "session_cookie_name", null)
                    session_timeout = lookup(authenticate_cognito.value, "session_timeout", null)
                    authentication_request_extra_params = try(authenticate_cognito.value.authentication_request_extra_params, {})
                }
            }
            
            dynamic "authenticate_oidc" {
                for_each = try(action.value.authenticate_oidc, null) != null ? [action.value.authenticate_oidc] : []
                content {
                    authorization_endpoint = authenticate_oidc.value.authorization_endpoint
                    client_id = authenticate_oidc.value.client_id
                    client_secret = authenticate_oidc.value.client_secret
                    issuer = authenticate_oidc.value.issuer
                    token_endpoint = authenticate_oidc.value.token_endpoint
                    user_info_endpoint = authenticate_oidc.value.user_info_endpoint
                    on_unauthenticated_request = lookup(authenticate_oidc.value, "on_unauthenticated_request", null)
                    scope = lookup(authenticate_oidc.value, "scope", null)
                    session_cookie_name = lookup(authenticate_oidc.value, "session_cookie_name", null)
                    session_timeout = lookup(authenticate_oidc.value, "session_timeout", null)
                    authentication_request_extra_params = try(authenticate_oidc.value.authentication_request_extra_params, {})
                }
            }
            
            dynamic "fixed_response" {
                for_each = try(action.value.fixed_response, null) != null ? [action.value.fixed_response] : []
                content {
                    content_type = fixed_response.value.content_type
                    message_body = lookup(fixed_response.value, "message_body", null)
                    status_code = lookup(fixed_response.value, "status_code", null)
                }
            }
            
            dynamic "forward" {
                for_each = try(action.value.weighted_forward, null) != null ? [action.value.weighted_forward] : []
                content {
                    dynamic "target_group" {
                        for_each = forward.value.target_groups
                        content {
                            arn = aws_lb_target_group.main[target_group.value.name].arn
                            weight = lookup(target_group.value, "weight", null)
                        }
                    }
                    dynamic "stickiness" {
                        for_each = try(forward.value.stickiness, null) != null ? [forward.value.stickiness] : []
                        content {
                            duration = stickiness.value.duration
                            enabled = lookup(stickiness.value, "enabled", false)
                        }
                    }
                }
            }
            
            dynamic "redirect" {
                for_each = try(action.value.redirect, null) != null ? [action.value.redirect] : []
                content {
                    status_code = redirect.value.status_code
                    host = lookup(redirect.value, "host", null)
                    path = lookup(redirect.value, "path", null)
                    port = lookup(redirect.value, "port", null)
                    protocol = lookup(redirect.value, "protocol", null)
                    query = lookup(redirect.value, "query", null)
                }
            }
        }
    }

    dynamic "condition" {
        for_each = try(each.value.conditions, [])
        content {
            dynamic "host_header" {
                for_each = try(condition.value.host_headers, null) != null ? [condition.value.host_headers] : []
                content {
                    values = host_header.value
                }
            }
            dynamic "http_header" {
                for_each = try(condition.value.http_headers, [])
                content {
                    http_header_name = http_header.value.http_header_name
                    values = http_header.value.values
                }
            }
            dynamic "http_request_method" {
                for_each = try(condition.value.http_request_methods, null) != null ? [condition.value.http_request_methods] : []
                content {
                    values = http_request_method.value
                }
            }
            dynamic "path_pattern" {
                for_each = try(condition.value.path_patterns, null) != null ? [condition.value.path_patterns] : []
                content {
                    values = path_pattern.value
                }
            }
            dynamic "query_string" {
                for_each = try(condition.value.query_strings, [])
                content {
                    key = lookup(query_string.value, "key", null)
                    value = query_string.value.value
                }
            }
            dynamic "source_ip" {
                for_each = try(condition.value.source_ips, null) != null ? [condition.value.source_ips] : []
                content {
                    values = source_ip.value
                }
            }
        }
    }
    tags = try(each.value.tags, {})
    depends_on = [aws_lb_listener.main, aws_lb_target_group.main]
}