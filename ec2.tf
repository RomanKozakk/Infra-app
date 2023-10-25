
/*
resource "aws_instance" "backend_instance" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = "t3.medium"
  key_name                    = "ec2-demo"
  subnet_id                   = aws_subnet.public_subnets[1].id
  security_groups             = [aws_security_group.private.id]
  associate_public_ip_address = "true"

  tags = {
    Name = "backend"
  }
}
resource "aws_instance" "frontend_instance" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = "t2.micro"
  key_name                    = "ec2-demo"
  subnet_id                   = aws_subnet.public_subnets[0].id
  security_groups             = [aws_security_group.private.id]
  associate_public_ip_address = "true"

  tags = {
    Name = "frontend"
  }
}
*/
