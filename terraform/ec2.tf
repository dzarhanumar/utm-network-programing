data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AMI owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# The bastion / Ansible control node - the ONLY instance with a public IP.
resource "aws_instance" "ansible_control" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids     = [aws_security_group.public_sg.id]
  key_name                    = aws_key_pair.generated.key_name
  associate_public_ip_address = true

  tags = {
    Name = "ansible-control"
  }
}

# Simulated network device #1 - private subnet, no public IP.
resource "aws_instance" "router1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.generated.key_name

  tags = {
    Name = "router1"
  }
}

# Simulated network device #2 - private subnet, no public IP.
resource "aws_instance" "router2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = aws_key_pair.generated.key_name

  tags = {
    Name = "router2"
  }
}
