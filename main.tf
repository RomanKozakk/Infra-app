provider "aws" {
  region                   = "eu-central-1"
  shared_credentials_files = ["C:/Users/User/.aws/credentials"]
}
#vpc
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my_vpc"
  }
}
#subnets
variable "public_subnet_cidr_blocks" {
  description = "Список CIDR-блоків для публічних сабнетів"
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
}
variable "private_subnet_cidr_blocks" {
  description = "Список CIDR-блоків для приватних сабнетів"
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20"]
}
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidr_blocks)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "public_subnet ${count.index}"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(var.azs, count.index) # Вибрати зону доступності для кожної підмережі

  tags = {
    Name = "private_subnet ${count.index}"
  }
}

/*
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "private_subnet ${count.index}"
  }
}
*/
/*
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name        = "my-db-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids  = concat(aws_subnet.private_subnets[1].id)
}
*/

# GATEWAY
resource "aws_internet_gateway" "my_ingateway" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "ingtw"
  }
}
output "internet_gateway_id" {
  value = aws_internet_gateway.my_ingateway.id
}
/*
#NAT
resource "aws_nat_gateway" "private_nat" {
  connectivity_type = "private"
  subnet_id         = aws_subnet.private_subnets.id
}
*/
#ROUTETABLES
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.my_vpc.id
}
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_ingateway.id
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.my_vpc.id
}
/*
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "10.0.128.0/20"
  nat_gateway_id         = aws_nat_gateway.private_nat.id
}
*/
# SECURITY GROUPS
/*resource "aws_security_group" "frontend_instance" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id
}
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Security group for frontend instances in the private subnet"

  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # можливо треба змінити
  }
}
*/
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.my_vpc.id
  dynamic "ingress" {
    for_each = ["22", "80"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["91.243.3.248/32"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.my_vpc.cidr_block]
  }
}


#остання версія амазон лінукс 2
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["amazon"]
}

