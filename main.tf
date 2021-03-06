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
# DATABASE ROUTE TABLE
#

resource "aws_route_table" "database" {
  count = var.create_vpc && var.create_database_subnet_route_table && length(var.database_subnets) > 0 ? var.create_database_transit_gateway_route ? 1 : length(var.database_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format("%s-${var.database_subnet_suffix}-rt", var.name)
    },
    var.tags,
    var.database_route_table_tags,
  )
}

#
# REDSHIFT ROUTE TABLE
#

resource "aws_route_table" "redshift" {
  count = var.create_vpc && var.create_redshift_subnet_route_table && length(var.redshift_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = "${var.name}-${var.redshift_subnet_suffix}"
    },
    var.tags,
    var.redshift_route_table_tags,
  )
}

#
# ELASTICACHE ROUTE TABLE
#

resource "aws_route_table" "elasticache" {
  count = var.create_vpc && var.create_elasticache_subnet_route_table && length(var.elasticache_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = "${var.name}-${var.elasticache_subnet_suffix}"
    },
    var.tags,
    var.elasticache_route_table_tags,
  )
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
# DATABASE SUBNETS
#

resource "aws_subnet" "database" {
  count = var.create_vpc && length(var.database_subnets) > 0 ? length(var.database_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.database_subnets[count.index]
  availability_zone               = data.aws_availability_zones.azs.names[count.index]
  assign_ipv6_address_on_creation = false

  tags = merge(
    {
      "Name" = format(
        "%s-${var.database_subnet_suffix}-%s",
        var.name,
        data.aws_availability_zones.azs.names[count.index]
      )
    },
    var.tags,
    var.database_subnet_tags,
  )
}

resource "aws_db_subnet_group" "database" {
  count = var.create_vpc && length(var.database_subnets) > 0 && var.create_database_subnet_group ? 1 : 0

  name        = lower(var.name)
  description = "Database subnet group for ${var.name}"
  subnet_ids  = aws_subnet.database.*.id

  tags = merge(
    {
      "Name" = format("%s", var.name)
    },
    var.tags,
    var.database_subnet_group_tags,
  )
}

#
# REDSHIFT SUBNETS
#

resource "aws_subnet" "redshift" {
  count = var.create_vpc && length(var.redshift_subnets) > 0 ? length(var.redshift_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.redshift_subnets[count.index]
  availability_zone               = data.aws_availability_zones.azs.names[count.index]
  assign_ipv6_address_on_creation = false


  tags = merge(
    {
      "Name" = format(
        "%s-${var.redshift_subnet_suffix}-%s",
        var.name,
        data.aws_availability_zones.azs.names[count.index]
      )
    },
    var.tags,
    var.redshift_subnet_tags,
  )
}

resource "aws_redshift_subnet_group" "redshift" {
  count = var.create_vpc && length(var.redshift_subnets) > 0 && var.create_redshift_subnet_group ? 1 : 0

  name        = lower(var.name)
  description = "Redshift subnet group for ${var.name}"
  subnet_ids  = aws_subnet.redshift.*.id

  tags = merge(
    {
      "Name" = format("%s", var.name)
    },
    var.tags,
    var.redshift_subnet_group_tags,
  )
}

#
# ELASTICACHE SUBNETS
#

resource "aws_subnet" "elasticache" {
  count = var.create_vpc && length(var.elasticache_subnets) > 0 ? length(var.elasticache_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.elasticache_subnets[count.index]
  availability_zone               = data.aws_availability_zones.azs.names[count.index]
  assign_ipv6_address_on_creation = false

  tags = merge(
    {
      "Name" = format(
        "%s-${var.elasticache_subnet_suffix}-%s",
        var.name,
        data.aws_availability_zones.azs.names[count.index]
      )
    },
    var.tags,
    var.elasticache_subnet_tags,
  )
}

resource "aws_elasticache_subnet_group" "elasticache" {
  count = var.create_vpc && length(var.elasticache_subnets) > 0 && var.create_elasticache_subnet_group ? 1 : 0

  name        = var.name
  description = "ElastiCache subnet group for ${var.name}"
  subnet_ids  = aws_subnet.elasticache.*.id
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

resource "aws_network_acl" "database" {
  count = var.create_vpc && length(var.database_subnets) > 0 ? 1 : 0

  vpc_id     = element(concat(aws_vpc.this.*.id, [""]), 0)
  subnet_ids = aws_subnet.database.*.id

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
      "Name" = format("%s-${var.database_subnet_suffix}-nacl", var.name)
    },
    var.tags,
    var.database_acl_tags,
  )
}

resource "aws_network_acl" "redshift" {
  count = var.create_vpc && length(var.redshift_subnets) > 0 ? 1 : 0

  vpc_id     = element(concat(aws_vpc.this.*.id, [""]), 0)
  subnet_ids = aws_subnet.redshift.*.id

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
      "Name" = format("%s-${var.redshift_subnet_suffix}-nacl", var.name)
    },
    var.tags,
    var.redshift_acl_tags,
  )
}

resource "aws_network_acl" "elasticache" {
  count = var.create_vpc && length(var.elasticache_subnets) > 0 ? 1 : 0

  vpc_id     = element(concat(aws_vpc.this.*.id, [""]), 0)
  subnet_ids = aws_subnet.elasticache.*.id

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
    cidr_block = aws_vpc.this[0].cidr_block
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      "Name" = format("%s-${var.elasticache_subnet_suffix}-nacl", var.name)
    },
    var.tags,
    var.elasticache_acl_tags,
  )
}

#
# TRANSIT GATEWAY RESOURCES
# 
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count              = var.create_vpc && var.attach_transit_gateway && length(var.private_subnets) > 0 ? 1 : 0
  subnet_ids         = aws_subnet.private.*.id
  vpc_id             = local.vpc_id
  transit_gateway_id = var.transit_gateway_id
  transit_gateway_default_route_table_association = var.transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation = var.transit_gateway_default_route_table_propagation

  tags = {
    "Name" = format("%s-${var.private_subnet_suffix}-tga", var.name)
  }
}

resource "aws_route" "tgw" {
  for_each = var.transit_gateway_routes

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = each.value["destination_cidr_block"]
  transit_gateway_id     = each.value["transit_gateway_id"]

}