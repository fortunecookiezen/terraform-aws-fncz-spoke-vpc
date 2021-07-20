resource "aws_route" "private" {
  for_each = var.transit_gateway_routes

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = each.value["destination_cidr_block"]
  transit_gateway_id     = each.value["transit_gateway_id"]

}

variable "transit_gateway_routes" {
  type = map(object({
    destination_cidr_block = string
    transit_gateway_id     = string
  }))
}
