# Create VPC in us-east-1
resource "aws_vpc" "vpc_east" {
  provider             = aws.east
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "VPC-East-Requester" }
}

# Public Subnet for our EC2
resource "aws_subnet" "subnet_east" {
  provider                = aws.east
  vpc_id                  = aws_vpc.vpc_east.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = { Name = "Subnet-East" }
}

# Internet Gateway so we can SSH into it
resource "aws_internet_gateway" "igw_east" {
  provider = aws.east
  vpc_id   = aws_vpc.vpc_east.id
}

# Route Table for Internet Access
resource "aws_route_table" "rt_east" {
  provider = aws.east
  vpc_id   = aws_vpc.vpc_east.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_east.id
  }
}

resource "aws_route_table_association" "a_east" {
  provider       = aws.east
  subnet_id      = aws_subnet.subnet_east.id
  route_table_id = aws_route_table.rt_east.id
}