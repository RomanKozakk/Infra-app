provider "aws" {
  region                   = "eu-central-1"
  shared_credentials_files = ["C:/Users/User/.aws/credentials"]
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "my_vpc"
  }
}

variable "public_subnet_cidr_blocks" {
  description = "Список CIDR-блоків для публічних сабнетів"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "private_subnet_cidr_blocks" {
  description = "Список CIDR-блоків для приватних сабнетів"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidr_blocks)

  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index}"
  }
}

resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet ${count.index}"
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name        = "my-db-subnet-group"
  description = "Subnet group for RDS"
  subnet_ids  = concat(aws_subnet.public_subnets[*].id, aws_subnet.private_subnets[*].id)
}

resource "aws_security_group" "frontend_instance" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.my_vpc.id
}
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Security group for frontend instances in the private subnet"

  vpc_id = aws_vpc.my_vpc.id

  # Дозволяємо з'єднання зі зовнішнього світу на порт 80 (HTTP)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # можливо треба змінити
  }
}

resource "aws_security_group" "ssh_sg" {
  name        = "ssh-sg"
  description = "Security group for SSH access"

  vpc_id = aws_vpc.my_vpc.id

  # Дозволюємо SSH зв'язок зі зовнішнього світу
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["91.243.3.248/32"]
  }
}

resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Security group for backend instances in the private subnet"

  vpc_id = aws_vpc.my_vpc.id

  # Дозволюємо з'єднання на порт бази даних (наприклад, порт 3306 для MySQL)
  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    # CIDR блок, який представляє базу даних (наприклад, 10.0.1.0/24)
    cidr_blocks = ["10.0.1.0/24"]
  }

  # Дозволюємо з'єднання з фронтенду (наприклад, на порт 80 для HTTP)
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    # CIDR блок, який представляє фронтенд (наприклад, 10.0.2.0/24)
    cidr_blocks = ["10.0.2.0/24"]
  }
}
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


# Create EC2 instances 
resource "aws_instance" "ci_cd_instance" {
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t2.micro"
  key_name      = "roma.pem"
  subnet_id     = aws_subnet.private_subnet[0].id
}

resource "aws_subnet" "private_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"   # Вкажіть відповідний CIDR-блок
  availability_zone       = "eu-central-1a" # Вкажіть відповідну зону доступності
  map_public_ip_on_launch = false
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "eschool" {
  count                   = length(var.private_subnet_cidr_blocks)
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = element(var.private_subnet_cidr_blocks, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = false
}

resource "aws_instance" "frontend_instance" {
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t2.micro"
  key_name      = "roma.pem"
  subnet_id     = aws_subnet.private_subnet[1].id
}

resource "aws_instance" "backend_instance" {
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.medium"
  key_name      = "roma.pem"
  subnet_id     = aws_subnet.private_subnet[2].id
}


resource "aws_subnet" "bastion" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = element(var.public_subnet_cidr_blocks, count.index)
  availability_zone       = element(var.azs, 0)
  count                   = length(var.public_subnet_cidr_blocks)
  map_public_ip_on_launch = true
}
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "sg for bastion host"
  vpc_id      = aws_vpc.my_vpc.id
}

resource "aws_security_group_rule" "bastion_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Вкажіть необхідний діапазон IP-адрес для доступу???
  security_group_id = aws_security_group.bastion.id
}


// load balancer
resource "aws_lb" "eschool" {
  name                       = "my-load-balancer"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = aws_subnet.eschool.*.id
  enable_deletion_protection = false
  enable_http2               = true
}

resource "aws_lb_target_group" "eschool" {
  name        = "my-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  target_type = "instance"
}

resource "aws_lb_listener" "eschool" {
  load_balancer_arn = aws_lb.eschool.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eschool.arn
  }
}



# Create Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "roma.pem"
  subnet_id              = element(aws_subnet.public_subnets[*].id, 0)
  vpc_security_group_ids = [aws_security_group.bastion.id]
  tags = {
    Name = "bastion-host"
  }
}


resource "aws_db_instance" "my_rds" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = "dbusername"
  password               = "dbpassword"
  db_name                = "mydatabase"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.backend_sg.id]          # Група безпеки
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name # Група підмереж
  multi_az               = false                                       # Якщо вам потрібен Multi-AZ (висока доступність)

  tags = {
    Name = "my-database"
  }
}
