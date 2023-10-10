/* Default Landing VPC module (public, private-nat, private subnets) & default vpc gateways
   Resource Naming rule
    VPC: VPC_[service name]_[purpose]_[env]_[region] ex) VPC_DKS_SVC_PROD_KR
    Subnet: sub_[zone]_[service name]_[purpose]_[env]_[az]_[region] ex) sub_public_dks_svc_prod_a_kr
    RouteTable: rtb_[zone]_[service name]_[purpose]_[env]_[az]_[region] ex) rtb_public_dks_svc_prod_a_kr
    Internet GW: igw_[service name]_[purpose]_[env]_[region] ex) igw_dks_svc_prod_kr
    EIP: eip_[name]_[service name]_[purpose]_[env]_[az]_[region] ex) eip_natgw_dks_svc_prod_c_kr
    NAT GW: natgw_[service name]_[purpose]_[env]_[az]_[region] ex) natgw_dks_svc_prod_a_kr
    NACL: nacl_[zone]_[service_name]_[purpose]_[env]_[az]_[region] ex) nacl_public_dks_svc_prod_g_kr
    Endpoints: ep_[type]_[aws service]_[service name]_[purpose]_[env]_[region] ex) ep_gateway_s3_dks_svc_prod_kr
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
    region_name = lower(var.region_name)
    svc_name = lower(var.svc_name)
    purpose = lower(var.purpose)
    env = lower(var.env)
    region_name_alias = lower(var.region_name_alias)
    suffix = "${local.svc_name}_${local.purpose}_${local.env}_${local.region_name_alias}"

    public_subnet_az_map = zipmap(var.az_names, aws_subnet.public.*.id)
    privnat_subnet_az_map = zipmap(var.az_names, aws_subnet.privnat.*.id)
    private_subnet_az_map = zipmap(var.az_names, aws_subnet.private.*.id)
    subnet_zone_map  = zipmap(["public", "privnat", "private"], [aws_subnet.public.*.id, aws_subnet.privnat.*.id, aws_subnet.private.*.id])
}

resource "aws_vpc" "main" {
    cidr_block = var.cidr_block
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        # Naming rule: VPC_[service name]_[purpose]_[env]_[region] ex) VPC_DKS_SVC_PROD_KR, VPC_DKS_MGMT_PROD_KR
        Name = format("VPC_%s_${upper(var.purpose)}_%s_%s", upper(var.svc_name), upper(var.env), upper(var.region_name_alias))
    }
    # kubernetes tag 때문에 추가, k8s가 추가한 tag 자동 삭제 방지용
    lifecycle {
        ignore_changes = [tags]
    }
}

# Public subnet define
resource "aws_subnet" "public" {
    count = length(var.public_cidrs)
    vpc_id = aws_vpc.main.id
    # if subnet_private_cidrs is null, automatically subnetting 19bit mask
    # cidrsubnet(var.cidr_block, 3, index(var.az_names, each.key)
    cidr_block = var.public_cidrs[count.index].cidr_block
    availability_zone = var.public_cidrs[count.index].availability_zone
    tags = {
        # Naming rule: sub_[zone]_[service name]_[purpose]_[env]_[az]_[region] ex) sub_public_dks_svc_prod_a_kr
        Name = format("sub_public_%s_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, substr(lower(var.public_cidrs[count.index].availability_zone),-1,-1), local.region_name_alias)
    }
    # kubernetes tag 때문에 추가, k8s가 추가한 tag 자동 삭제 방지용
    lifecycle {
        ignore_changes = [tags]
    }
}

# Private subnet with NAT gateway define
resource "aws_subnet" "privnat" {
    count = length(var.privnat_cidrs)
    vpc_id = aws_vpc.main.id
    cidr_block = var.privnat_cidrs[count.index].cidr_block
    availability_zone = var.privnat_cidrs[count.index].availability_zone
    tags = {
        # Naming rule: sub_[zone]_[service name]_[purpose]_[env]_[az]_[region] ex) sub_privnat_dks_svc_prod_a_kr
        Name = format("sub_privnat_%s_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, substr(lower(var.privnat_cidrs[count.index].availability_zone), -1, -1), local.region_name_alias)
    }
    # kubernetes tag 때문에 추가, k8s가 추가한 tag 자동 삭제 방지용
    lifecycle {
        ignore_changes = [tags]
    }
}

# Private subnet w/o NAT gateway define
resource "aws_subnet" "private" {
    count = length(var.private_cidrs)
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_cidrs[count.index].cidr_block
    availability_zone = var.private_cidrs[count.index].availability_zone
    tags = {
        # Naming rule: sub_[zone]_[service name]_[purpose]_[env]_[az]_[region] ex) sub_private_dks_svc_prod_a_kr
        Name = format("sub_private_%s_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, substr(lower(var.private_cidrs[count.index].availability_zone), -1, -1), local.region_name_alias)
    }
    # kubernetes tag 때문에 추가, k8s가 추가한 tag 자동 삭제 방지용
    lifecycle {
        ignore_changes = [tags]
    }
}

# create internet gateway
resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id
    tags = {
        # Naming rule: igw_[service name]_[purpose]_[env]_[region] ex) igw_dks_svc_prod_kr
        Name = format("igw_%s", local.suffix)
    }
}

# create nat gateway
resource "aws_eip" "natgw" {
    for_each = toset(var.az_names)
    vpc = true
    
    tags = {
        # Naming rule: eip_natgw_[svc]_[purpose]_[env]_[az]_[region] ex) eip_natgw_dks_svc_prod_kr
        Name = format("eip_natgw_%s_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, substr(lower(each.key), -1, -1), local.region_name_alias)
    }
}

resource "aws_nat_gateway" "main" {
    for_each = toset(var.az_names)
    connectivity_type = "public" # public for internet, private for other vpcs
    
    allocation_id = aws_eip.natgw[each.key].allocation_id
    subnet_id = local.public_subnet_az_map[each.key] # NAT gateway must be on public subnets
    
    tags = {
        # Naming rule: natgw_[service name]_[purpose]_[env]_[az]_[region] ex) natgw_dks_svc_prod_a_kr
        Name = format("natgw_%s_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, substr(lower(each.key),-1,-1), local.region_name_alias)
    }
    depends_on = [aws_internet_gateway.main]
}

# Create route table
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }
    tags = {
        # Naming rule: rtb_[zone]_[service name]_[purpose]_[env]_[az]_[region] ex) rtb_public_dks_svc_prod_a_kr
        Name = format("rtb_public_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, local.region_name_alias)
    }
    lifecycle {
        ignore_changes = [route]
    }
}

resource "aws_route_table" "privnat" {
    for_each = local.privnat_subnet_az_map
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.main[each.key].id
    }

    tags = {
        # Naming rule: rtb_[zone]_[service_name]_[purpose]_[env]_[az]_[region] ex) rtb_privnat_dks_svc_prod_a_kr
        Name = format("rtb_privnat_%s_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, substr(lower(each.key),-1,-1), local.region_name_alias)
    }
    lifecycle {
        ignore_changes = [route]
    }
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id
    tags = {
        # Naming rule: rtb_[zone]_[service_name]_[purpose]_[env]_[az]_[region] ex) rtb_private_dks_svc_prod_a_kr
        Name = format("rtb_private_%s_%s_%s_%s", local.svc_name, local.purpose, local.env, local.region_name_alias)
    }
    lifecycle {
        ignore_changes = [route]
    }
}

# Route table association
resource "aws_route_table_association" "public" {
    for_each = local.public_subnet_az_map
    subnet_id = each.value
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "privnat" {
    for_each = local.privnat_subnet_az_map
    subnet_id = each.value
    route_table_id = [ for k, v in aws_route_table.privnat : v.id if k == each.key ][0]
}

resource "aws_route_table_association" "private" {
    for_each = local.private_subnet_az_map
    subnet_id = each.value
    route_table_id = aws_route_table.private.id
}

# network-acl default permit-all
resource "aws_network_acl" "nacl" {
    for_each = var.nacl_policy
    vpc_id = aws_vpc.main.id

    subnet_ids = local.subnet_zone_map[each.key]

    dynamic "ingress" {
        for_each = each.value.ingresses
        content {
            protocol = ingress.value.protocol
            rule_no = ingress.value.rule_no
            action = ingress.value.action
            cidr_block = ingress.value.cidr_block
            from_port = ingress.value.from_port
            to_port = ingress.value.to_port
        }
    }
    dynamic "egress" {
        for_each = each.value.egresses
        content {
            protocol = egress.value.protocol
            rule_no = egress.value.rule_no
            action = egress.value.action
            cidr_block = egress.value.cidr_block
            from_port = egress.value.from_port
            to_port = egress.value.to_port            
        }
    }
    tags = {
        # Naming rule: nacl_[zone]_[service_name]_[purpose]_[env]_[az]_[region] ex) nacl_public_dks_svc_prod_g_kr
        Name = format("nacl_%s_%s_%s_%s_%s", each.key, local.svc_name, local.purpose, local.env, local.region_name_alias)
    }
}