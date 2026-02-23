# Create VPC in us-west-2
resource "aws_vpc" "vpc_west" {
  provider             = aws.west
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "VPC-West-Accepter" }
}

# Public Subnet
resource "aws_subnet" "subnet_west" {
  provider                = aws.west
  vpc_id                  = aws_vpc.vpc_west.id
  cidr_block              = "10.2.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
  tags = { Name = "Subnet-West" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw_west" {
  provider = aws.west
  vpc_id   = aws_vpc.vpc_west.id
}

# Route Table
resource "aws_route_table" "rt_west" {
  provider = aws.west
  vpc_id   = aws_vpc.vpc_west.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_west.id
  }
}

resource "aws_route_table_association" "a_west" {
  provider       = aws.west
  subnet_id      = aws_subnet.subnet_west.id
  route_table_id = aws_route_table.rt_west.id
}