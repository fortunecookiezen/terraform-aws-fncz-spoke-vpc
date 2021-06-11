# we attempt to be fully region independent
data "aws_region" "current" {}
data "aws_availability_zones" "azs" {
  state = "available"
}