resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true # This both dns_hostnames and dns_support, will get used for the add-ons. like clinet VPN, and EFS and EBS CSI driver. 
  enable_dns_hostnames = true

  tags = {
    Name = "${local.env}-main"
  }
}