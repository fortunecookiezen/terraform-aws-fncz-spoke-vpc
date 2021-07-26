output "vpc_id" {
  description = "The ID of the VPC"
  value       = concat(aws_vpc.this.*.id, [""])[0]
}
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private.*.id
}
