# VPC in Region A
resource "aws_vpc" "vpc_a" {
  provider   = aws.region_a
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "VPC-A-East" }
}

# VPC in Region B
resource "aws_vpc" "vpc_b" {
  provider   = aws.region_b
  cidr_block = "10.2.0.0/16"
  tags       = { Name = "VPC-B-West" }
}

# 1. Requester side (Region East)
resource "aws_vpc_peering_connection" "east_to_west" {
  provider      = aws.east
  vpc_id        = aws_vpc.vpc_east.id
  peer_vpc_id   = aws_vpc.vpc_west.id
  peer_region   = "us-west-2" # The region of the accepter
  
  tags = {
    Name = "VPC-Peering-East-West"
  }
}

# 2. Accepter side (Region West)
resource "aws_vpc_peering_connection_accepter" "west_accepter" {
  provider                  = aws.west
  vpc_peering_connection_id = aws_vpc_peering_connection.east_to_west.id
  auto_accept               = true

  tags = {
    Name = "VPC-Peering-Acceptor-West"
  }
}