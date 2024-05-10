#Definir padrões de uso do meu ambiente na AWS
provider "aws" {
 region = "us-east-1"
 shared_config_files      = [".aws/config"]
 shared_credentials_files = [".aws/config"]
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
  key_name = "Chave-Linux" #alterar da sua chavess
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.Grupo-Sec-Linux.id]
  user_data =   <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd git
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo yum install -y amazon-efs-utils
              sudo mkdir /mnt/efs
              echo "${aws_efs_file_system.efs_vini.id}:/ /mnt/efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
              sudo mount -a
              sudo rm -rf /var/www/html/*
              sudo git clone https://github.com/FofuxoSibov/sitebike /mnt/efs
              sudo mv /mnt/efs/* /var/www/html/
              EOF
    tags = {
      Name = "Amazon-Linux-Vini"
  }
}

resource "aws_instance" "Amazon-Linux-2" {
  ami                    = "ami-07caf09b362be10b8"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Subrede-Pub1.id
  key_name = "Chave-Linux" #alterar da sua chaves
  associate_public_ip_address = "true"
  vpc_security_group_ids = [aws_security_group.Grupo-Sec-Linux.id]
  user_data =   <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd git
              sudo systemctl start httpd
              sudo systemctl enable httpd
              sudo yum install -y amazon-efs-utils
              sudo mkdir /mnt/efs
              echo "${aws_efs_file_system.efs_vini.id}:/ /mnt/efs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
              sudo mount -a
              sudo rm -rf /var/www/html/*
              sudo git clone https://github.com/FofuxoSibov/sitebike /mnt/efs
              sudo mv /mnt/efs/* /var/www/html/
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
  #Liberar porta HTTPs
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    #Liberar porta TCP
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
  creation_token = "vinicius48"

    tags ={
        Name="vinicius48"
    }
}

resource "aws_efs_mount_target" "mount_target_pub1a" {
  file_system_id = aws_efs_file_system.efs_vini.id
  subnet_id = aws_subnet.Subrede-Pub1.id
  security_groups = [aws_security_group.Grupo-Sec-Linux.id]
}

