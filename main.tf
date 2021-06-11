locals {
  max_subnet_length = max(
    length(var.private_subnets),
    length(var.isolated_subnets)
  )

  # nat_gateway_count = var.enable_nat_gateway ? 0 : length(var.private_subnets)

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = element(
    concat(
      aws_vpc_ipv4_cidr_block_association.this.*.vpc_id,
      aws_vpc.this.*.id,
      [""],
    ),
    0,
  )
}

resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    {
      "Name"   = format("%s", var.name)
      "Region" = format("%s", data.aws_region.current.name)
    },
    var.tags,
    var.vpc_tags,
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = var.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

# manage the default security group, no ingress or egress mean no rules
resource "aws_default_security_group" "this" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.this[0].id
  tags = {
    "Name" = "default"
  }
}

#manage the default network acl to detect drift
resource "aws_default_network_acl" "this" {
  count = var.create_vpc ? 1 : 0

  default_network_acl_id = aws_vpc.this[0].default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_vpc.this[0].cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    "Name" = "default"
  }
}

#
# ROUTES & ROUTE TABLES
#


#
# PRIVATE ROUTES
#

resource "aws_route_table" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  dynamic "route" {
    for_each = var.private_route_table_routes
    content {
      # One of the following destinations must be provided
      cidr_block                 = lookup(route.value, "cidr_block", null)
      destination_prefix_list_id = lookup(route.value, "destination_prefix_list_id", null)

      # One of the following targets must be provided
      gateway_id                = lookup(route.value, "gateway_id", null)
      instance_id               = lookup(route.value, "instance_id", null)
      nat_gateway_id            = lookup(route.value, "nat_gateway_id", null)
      network_interface_id      = lookup(route.value, "network_interface_id", null)
      transit_gateway_id        = lookup(route.value, "transit_gateway_id", null)
      vpc_endpoint_id           = lookup(route.value, "vpc_endpoint_id", null)
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
    }
  }

  tags = merge(
    {
      "Name" = format("%s-${var.private_subnet_suffix}-rt", var.name)
    },
    var.tags,
    var.private_route_table_tags,
  )
}

resource "aws_route_table_association" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private[0].id
}


#
# ISOLATED ROUTE TABLE
#

resource "aws_route_table" "isolated" {
  count = var.create_vpc && length(var.isolated_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format("%s-${var.isolated_subnet_suffix}-rt", var.name)
    },
    var.tags,
    var.isolated_route_table_tags,
  )
}

resource "aws_route_table_association" "isolated" {
  count = var.create_vpc && length(var.isolated_subnets) > 0 ? length(var.isolated_subnets) : 0

  subnet_id      = element(aws_subnet.isolated.*.id, count.index)
  route_table_id = aws_route_table.isolated[0].id
}

#
# PRIVATE SUBNETS
#

resource "aws_subnet" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 && (length(var.private_subnets) <= length(data.aws_availability_zones.azs)) ? length(var.private_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.private_subnets[count.index]
  availability_zone               = data.aws_availability_zones.azs.names[count.index]
  assign_ipv6_address_on_creation = false

  tags = merge(
    {
      "Name" = format(
        "%s-${var.private_subnet_suffix}-%s",
        var.name,
        data.aws_availability_zones.azs.names[count.index]
      )
    },
    var.tags,
    var.private_subnet_tags,
  )
}

#
# ISOLATED SUBNETS
#

resource "aws_subnet" "isolated" {
  count = var.create_vpc && length(var.isolated_subnets) > 0 && (length(var.isolated_subnets) <= length(data.aws_availability_zones.azs)) ? length(var.isolated_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.isolated_subnets[count.index]
  availability_zone               = data.aws_availability_zones.azs.names[count.index]
  assign_ipv6_address_on_creation = false

  tags = merge(
    {
      "Name" = format(
        "%s-${var.isolated_subnet_suffix}-%s",
        var.name,
        data.aws_availability_zones.azs.names[count.index]
      )
    },
    var.tags,
    var.isolated_subnet_tags,
  )
}

#
# NACLS - we don't really use these for access control, so they're pretty loose.
#
resource "aws_network_acl" "private" {
  count = var.create_vpc && length(var.private_subnets) > 0 ? 1 : 0

  vpc_id     = element(concat(aws_vpc.this.*.id, [""]), 0)
  subnet_ids = aws_subnet.private.*.id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      "Name" = format("%s-${var.private_subnet_suffix}-nacl", var.name)
    },
    var.tags,
    var.private_acl_tags,
  )
}

resource "aws_network_acl" "isolated" {
  count = var.create_vpc && length(var.isolated_subnets) > 0 ? 1 : 0

  vpc_id     = element(concat(aws_vpc.this.*.id, [""]), 0)
  subnet_ids = aws_subnet.isolated.*.id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_vpc.this[0].cidr_block
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0" #leaving this here so it can talk to s3 gateway endpoints
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      "Name" = format("%s-${var.isolated_subnet_suffix}-nacl", var.name)
    },
    var.tags,
    var.isolated_acl_tags,
  )
}

#
# TRANSIT GATEWAY RESOURCES
# 
# resource "aws_ec2_transit_gateway_vpc_attachment" "this" {

# }
