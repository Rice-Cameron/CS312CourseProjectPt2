provider "aws" {
  region                  = var.aws_region
  shared_credentials_files = ["~/.aws/credentials"]
}

# VPC Configuration
resource "aws_vpc" "minecraft_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "minecraft-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "minecraft_igw" {
  vpc_id = aws_vpc.minecraft_vpc.id

  tags = {
    Name = "minecraft-igw"
  }
}

# Public Subnet
resource "aws_subnet" "minecraft_public_subnet" {
  vpc_id                  = aws_vpc.minecraft_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "minecraft-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "minecraft_route_table" {
  vpc_id = aws_vpc.minecraft_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minecraft_igw.id
  }

  tags = {
    Name = "minecraft-route-table"
  }
}

# Route Table Association
resource "aws_route_table_association" "minecraft_route_assoc" {
  subnet_id      = aws_subnet.minecraft_public_subnet.id
  route_table_id = aws_route_table.minecraft_route_table.id
}

# Security Group
resource "aws_security_group" "minecraft_sg" {
  name        = "minecraft-sg"
  description = "Security group for Minecraft server"
  vpc_id      = aws_vpc.minecraft_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "minecraft-sg"
  }
}

# Create key pair in AWS
resource "tls_private_key" "minecraft_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "minecraft_key" {
  key_name   = "minecraft-server-ssh"
  public_key = tls_private_key.minecraft_key.public_key_openssh
}

# Save the private key to a file
resource "local_file" "private_key" {
  content  = tls_private_key.minecraft_key.private_key_pem
  filename = "${path.module}/minecraft-server-ssh.pem"
  file_permission = "0400"
}

# EC2 Instance
resource "aws_instance" "minecraft_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.minecraft_public_subnet.id
  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]
  key_name               = aws_key_pair.minecraft_key.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "minecraft-server"
  }
}

# Output the public IP
output "minecraft_server_ip" {
  value = aws_instance.minecraft_server.public_ip
  description = "Public IP address of the Minecraft server"
} 