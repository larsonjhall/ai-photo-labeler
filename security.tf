# Security Group in East (Allows SSH and ICMP/Ping from West VPC)
resource "aws_security_group" "sg_east" {
  provider = aws.east
  name     = "allow_west_vpc"
  vpc_id   = aws_vpc.vpc_east.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere (for you to log in)
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_west.cidr_block] # Allow Ping from West
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group in West
resource "aws_security_group" "sg_west" {
  provider = aws.west
  name     = "allow_east_vpc"
  vpc_id   = aws_vpc.vpc_west.id

  # THIS IS THE MISSING PIECE: Allow Ping from East
  ingress {
    from_port   = -1            # -1 means "All" for ICMP
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.1.0.0/16"] # The CIDR of your EAST VPC
  }

  # Allow SSH from anywhere (so you can troubleshoot later)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}