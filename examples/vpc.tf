module "vpc" {
  source = "../"
  name   = "test"
  cidr   = "10.10.0.0/20"

  private_subnets  = ["10.10.4.0/24", "10.10.5.0/24", "10.10.6.0/24", "10.10.7.0/24"]
  isolated_subnets = ["10.10.8.0/24", "10.10.9.0/24", "10.10.10.0/24", "10.10.11.0/24"]

  transit_gateway_routes = {
    default = {
      destination_cidr_block = "0.0.0.0/0"
      transit_gateway_id     = "tgw-005ea974aa5468d79"
    }
    datacenter = {
      destination_cidr_block = "10.0.0.0/8"
      transit_gateway_id     = "tgw-005ea974aa5468d79"
    }
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  vpc_tags = {
    PCI = "false"
  }
}
