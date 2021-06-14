## booleans first
variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}


variable "create_database_subnet_route_table" {
  description = "Controls if separate route table for database should be created"
  type        = bool
  default     = false
}

variable "create_redshift_subnet_route_table" {
  description = "Controls if separate route table for redshift should be created"
  type        = bool
  default     = false
}

variable "enable_public_redshift" {
  description = "Controls if redshift should have public routing table"
  type        = bool
  default     = false
}

variable "create_elasticache_subnet_route_table" {
  description = "Controls if separate route table for elasticache should be created"
  type        = bool
  default     = false
}

variable "create_database_subnet_group" {
  description = "Controls if database subnet group should be created (n.b. database_subnets must also be set)"
  type        = bool
  default     = true
}

variable "create_elasticache_subnet_group" {
  description = "Controls if elasticache subnet group should be created"
  type        = bool
  default     = true
}

variable "create_redshift_subnet_group" {
  description = "Controls if redshift subnet group should be created"
  type        = bool
  default     = true
}

variable "create_database_transit_gateway_route" {
  description = "Controls if an internet gateway route for public database access should be created"
  type        = bool
  default     = false
}

# strings

variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = ""
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "0.0.0.0/0"
}

variable "secondary_cidr_blocks" {
  description = "List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool"
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "isolated_subnets" {
  description = "A list of non-routable subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "database_subnets" {
  description = "A list of database subnets"
  type        = list(string)
  default     = []
}

variable "redshift_subnets" {
  description = "A list of redshift subnets"
  type        = list(string)
  default     = []
}

variable "elasticache_subnets" {
  description = "A list of elasticache subnets"
  type        = list(string)
  default     = []
}

variable "private_route_table_routes" {
  description = "Configuration block of routes. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_route_table#route"
  type        = list(map(string))
  default     = []
}

variable "private_subnet_suffix" {
  description = "Suffix to append to private subnets name"
  type        = string
  default     = "private"
}

variable "isolated_subnet_suffix" {
  description = "Suffix to append to outpost subnets name"
  type        = string
  default     = "isolated"
}

variable "database_subnet_suffix" {
  description = "Suffix to append to database subnets name"
  type        = string
  default     = "db"
}

variable "redshift_subnet_suffix" {
  description = "Suffix to append to redshift subnets name"
  type        = string
  default     = "redshift"
}

variable "elasticache_subnet_suffix" {
  description = "Suffix to append to elasticache subnets name"
  type        = string
  default     = "elasticache"
}


# maps
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_tags" {
  description = "Additional tags for the VPC"
  type        = map(string)
  default     = {}
}

variable "private_route_table_tags" {
  description = "Additional tags for the private route tables"
  type        = map(string)
  default     = {}
}

variable "isolated_route_table_tags" {
  description = "Additional tags for the isolated route tables"
  type        = map(string)
  default     = {}
}

variable "database_route_table_tags" {
  description = "Additional tags for the database route tables"
  type        = map(string)
  default     = {}
}

variable "redshift_route_table_tags" {
  description = "Additional tags for the redshift route tables"
  type        = map(string)
  default     = {}
}

variable "elasticache_route_table_tags" {
  description = "Additional tags for the elasticache route tables"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default     = {}
}

variable "isolated_subnet_tags" {
  description = "Additional tags for the isolated subnets"
  type        = map(string)
  default     = {}
}

variable "database_subnet_tags" {
  description = "Additional tags for the database subnets"
  type        = map(string)
  default     = {}
}

variable "database_subnet_group_tags" {
  description = "Additional tags for the database subnet group"
  type        = map(string)
  default     = {}
}

variable "redshift_subnet_tags" {
  description = "Additional tags for the redshift subnets"
  type        = map(string)
  default     = {}
}

variable "redshift_subnet_group_tags" {
  description = "Additional tags for the redshift subnet group"
  type        = map(string)
  default     = {}
}

variable "elasticache_subnet_tags" {
  description = "Additional tags for the elasticache subnets"
  type        = map(string)
  default     = {}
}

variable "private_acl_tags" {
  description = "Additional tags for the private subnets network ACL"
  type        = map(string)
  default     = {}
}

variable "isolated_acl_tags" {
  description = "Additional tags for the isolated subnets network ACL"
  type        = map(string)
  default     = {}
}

variable "database_acl_tags" {
  description = "Additional tags for the database subnets network ACL"
  type        = map(string)
  default     = {}
}

variable "redshift_acl_tags" {
  description = "Additional tags for the redshift subnets network ACL"
  type        = map(string)
  default     = {}
}

variable "elasticache_acl_tags" {
  description = "Additional tags for the elasticache subnets network ACL"
  type        = map(string)
  default     = {}
}
