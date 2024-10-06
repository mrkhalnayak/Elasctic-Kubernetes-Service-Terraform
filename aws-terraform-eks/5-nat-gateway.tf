# Elastic IP. Because the NAT gateway required Elastic IP.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.env}-nat"
  }
}

# NAT gateway for the VPC.
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_zone1.id

  tags = {
    Name = "${local.env}-nat"
  }

  depends_on = [aws_internet_gateway.igw] # here it will depend on the Internet gateway, until IGW is not get created nat-gateway will not be get created. 
}

# We need to create NAT-Gateway in one of public subnet with default route to the internet. 