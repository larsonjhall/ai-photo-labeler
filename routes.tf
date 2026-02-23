# Route in East Route Table to reach West VPC
resource "aws_route" "east_to_west" {
  provider                  = aws.east
  route_table_id            = aws_route_table.rt_east.id
  destination_cidr_block    = aws_vpc.vpc_west.cidr_block # 10.2.0.0/16
  vpc_peering_connection_id = aws_vpc_peering_connection.east_to_west.id
}

# Route in West Route Table to reach East VPC
resource "aws_route" "west_to_east" {
  provider                  = aws.west
  route_table_id            = aws_route_table.rt_west.id
  destination_cidr_block    = aws_vpc.vpc_east.cidr_block # 10.1.0.0/16
  vpc_peering_connection_id = aws_vpc_peering_connection.east_to_west.id
}