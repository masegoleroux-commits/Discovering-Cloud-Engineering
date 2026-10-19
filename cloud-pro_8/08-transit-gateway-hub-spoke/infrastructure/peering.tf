# VPC peering replaces the Transit Gateway (blocked in this account by an
# organization SCP). Peering is free and, unlike a TGW, NOT transitive:
# app can reach shared and shared can reach data, but app cannot reach data
# through shared. That gives the same segmentation the two TGW route tables did.
#
#   shared <-> app   always
#   shared <-> data  always
#   app    <-> data  only when var.allow_app_to_data = true

locals {
  peerings = merge(
    {
      "shared-app"  = { a = "shared", b = "app" }
      "shared-data" = { a = "shared", b = "data" }
    },
    var.allow_app_to_data ? { "app-data" = { a = "app", b = "data" } } : {}
  )

  # Each peering needs a route in BOTH VPCs' route tables, keyed "from->to"
  peering_routes = merge([
    for k, p in local.peerings : {
      "${p.a}->${p.b}" = { peering = k, from = p.a, to = p.b }
      "${p.b}->${p.a}" = { peering = k, from = p.b, to = p.a }
    }
  ]...)
}

resource "aws_vpc_peering_connection" "this" {
  for_each    = local.peerings
  vpc_id      = aws_vpc.this[each.value.a].id
  peer_vpc_id = aws_vpc.this[each.value.b].id
  auto_accept = true # same account and region, so it can accept itself
  tags        = { Name = "${local.name_prefix}-${each.key}-pcx" }
}

resource "aws_route" "peering" {
  for_each                  = local.peering_routes
  route_table_id            = aws_route_table.this[each.value.from].id
  destination_cidr_block    = var.vpc_cidrs[each.value.to]
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.value.peering].id
}
