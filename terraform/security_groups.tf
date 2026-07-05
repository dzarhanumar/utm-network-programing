# Attached to ansible-control (public subnet).
# Only YOUR laptop's IP can SSH into it - nobody else on the internet can.
resource "aws_security_group" "public_sg" {
  name        = "${var.project_name}-public-sg"
  description = "Allow SSH from my laptop only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my laptop"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-public-sg"
  }
}

# Attached to router1 / router2 (private subnet).
# Only instances carrying the public_sg (i.e. ansible-control) can SSH in.
# Nothing on the internet can reach this security group at all, because
# the private subnet has no route to the internet gateway in the first place.
resource "aws_security_group" "private_sg" {
  name        = "${var.project_name}-private-sg"
  description = "Allow SSH only from the ansible-control bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from ansible-control only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-sg"
  }
}
