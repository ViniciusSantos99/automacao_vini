#Chamada da Extensão Terraform - Precisa estar instalado anteriormente
terraform {
  required_version = ">= 1.3.0" # Obrigatorio estar com a versão 1.3.0 ou superior

  #Escolher o provedor - AWS
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.60.0"
    }
  }
}

#Definir padrões de uso do meu ambiente na AWS
provider "aws" {
  
  region = "us-east-1" #Definir Região
  shared_config_files = ["C:/Users/48981581886/.aws/config"] 
  shared_credentials_files = ["C:/Users/48981581886/.aws/credentials"] #Definir ID conta e Key

  default_tags {
    tags = {
      owner      = "Vinicius"
      managed-by = "Vinicius134"
    }
  }
}

# VPC
resource "aws_vpc" "VPC-CloudPlay" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Name = "VPC-CloudPlay"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "IGW-CloudPlay" {
  vpc_id = aws_vpc.VPC-CloudPlay.id

  tags = {
    Name = "IGW-CloudPlay"
  }
}

#ASSOCIAR A INTERNET GATEWAY A VPC
# resource "aws_internet_gateway_attachment" "IGW-ASSOCIAR" {
#   internet_gateway_id = aws_internet_gateway.IGW-CloudPlay.id
#   vpc_id = aws_vpc.VPC-CloudPlay.id
# }

# SUBNET Subrede-Pub1
resource "aws_subnet" "Subrede-Pub1" {
  vpc_id                  = aws_vpc.VPC-CloudPlay.id
  cidr_block              = "192.168.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "us-east-1a"

  tags = {
    Name = "Subrede-Pub1"
  }
}

# SUBNET Subrede-Pub2
resource "aws_subnet" "Subrede-Pub2" {
  vpc_id            = aws_vpc.VPC-CloudPlay.id
  cidr_block        = "192.168.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Subrede-Pub1"
  }
}

# ROUTE TABLE Publica
resource "aws_route_table" "Rotas-CloudPlay-Pub" {
  vpc_id = aws_vpc.VPC-CloudPlay.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW-CloudPlay.id
  }

  tags = {
    Name = "Rotas-CloudPlay-Pub"
  }
}


# SUBNET ASSOCIATION Pub
resource "aws_route_table_association" "Subrede-Pub" {
  subnet_id      = aws_subnet.Subrede-Pub1.id
  route_table_id = aws_route_table.Rotas-CloudPlay-Pub.id
}
# SUBNET ASSOCIATION Pub
resource "aws_route_table_association" "Subrede-Pub1" {
  subnet_id      = aws_subnet.Subrede-Pub2.id
  route_table_id = aws_route_table.Rotas-CloudPlay-Pub.id
}

resource "aws_instance" "Amazon-Linux" {
  ami                    = "ami-07caf09b362be10b8"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Subrede-Pub1.id
  key_name = "Chave-Linux" #alterar da sua chave
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.Grupo-Sec-Linux.id]
  user_data =  <<-EOF
                #!/bin/bash

                # Atualizar o hostname 
                sudo hostnamectl set-hostname amazon-linux

                bash

                # Atualizar todos os pacotes do sistema
                sudo yum update -y

                # Instalar o Apache
                sudo yum install -y httpd

                # Habilitar o Apache para iniciar no boot
                sudo systemctl enable httpd

                # Habilitar o iniciar no boot
                sudo systemctl start httpd

                # Instalar o Git
                sudo yum install -y git

                # Clonar o repositório Git
                sudo git clone https://github.com/FofuxoSibov/sitebike

                # Mover os arquivos para o diretório do Apache
                sudo mv sitebike/* /var/www/html/

                #Instalar efs untils 
                sudo yum install -y amazon-efs-utils

                # Montar o sistema de arquivos EFS
                sudo mkdir /mnt/efs
                sudo mount -t efs ${aws_efs_file_system.efs_vini.id}:/ /mnt/efs
                EOF
    tags = {
      Name = "Amazon-Linux-Vini"
  }
}

resource "aws_instance" "Amazon-Linux-2" {
  ami                    = "ami-07caf09b362be10b8"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Subrede-Pub2.id
  key_name = "Chave-Linux" #alterar da sua chave
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.Grupo-Sec-Linux.id]
  user_data =   <<-EOF
                #!/bin/bash

                # Atualizar o hostname 
                sudo hostnamectl set-hostname amazon-linux2

                bash

                # Atualizar todos os pacotes do sistema
                sudo yum update -y

                # Instalar o Git
                sudo yum install -y git

                # Montar o sistema de arquivos EFS
                sudo mkdir /mnt/efs
                sudo mount -t efs ${aws_efs_file_system.efs_vini.id}:/ /mnt/efs
                EOF
    tags = {
      Name = "Amazon-Linux-Vini-2"
  }
}

resource "aws_security_group" "Grupo-Sec-Linux" {
  name        = "Grupo-Sec-Linux"
  description = "Libera SSH e HTTP."
  vpc_id = aws_vpc.VPC-CloudPlay.id


  #Liberar porta SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #Liberar porta HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    #Liberar porta TCPs
  ingress {
    from_port   = 2049
    to_port     = 2049
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

resource "aws_efs_file_system" "efs_vini" {
  creation_token = "exemplo"
  performance_mode = "generalPurpose"
  throughput_mode = "bursting"
}

resource "aws_efs_mount_target" "mount_target_pub1a" {
  file_system_id = aws_efs_file_system.efs_vini.id
  subnet_id = aws_subnet.Subrede-Pub1.id
  security_groups = [aws_security_group.Grupo-Sec-Linux.id]
}

resource "aws_efs_mount_target" "mount_target_pub1b" {
  file_system_id = aws_efs_file_system.efs_vini.id
  subnet_id = aws_subnet.Subrede-Pub2.id
  security_groups = [aws_security_group.Grupo-Sec-Linux.id]
}


