# EC2 in us-east-1
resource "aws_instance" "east_instance" {
  provider      = aws.east
  ami           = "ami-0c7217cdde317cfec" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_east.id
  vpc_security_group_ids = [aws_security_group.sg_east.id]
  
  # ADD THIS LINE
  key_name      = "my-peering-key"

  tags = { Name = "East-Test-Server" }
}

# EC2 in us-west-2
resource "aws_instance" "west_instance" {
  provider      = aws.west
  ami           = "ami-03d5c68bab01f3496"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet_west.id
  vpc_security_group_ids = [aws_security_group.sg_west.id]

  # ADD THIS LINE
  key_name      = "my-peering-key"

  tags = { Name = "West-Test-Server" }
}

output "east_public_ip" { value = aws_instance.east_instance.public_ip }
output "west_private_ip" { value = aws_instance.west_instance.private_ip }