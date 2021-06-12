# Define Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = {}
  secret_key = {}
}

#create network for VM to leave onto---------------------

#define VPC
resource "aws_vpc" "prod_lan" {
  cidr_block       = "10.0.0.0/16"
}

# create internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_lan.id
}

#define network routing 

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod_lan.id

  route {
    #set defualt route
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#create subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.prod_lan.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "is-east-1a"
  }
}

#subnet association with routing table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

#setup security for webserver
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = aws_vpc.prod_lan.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [0.0.0.0/0]
    

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_webhttp"
  }
}

#creating network interface for vm ip 10.0.1.51 in our subnet-1

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.51"]
  security_groups = [aws_security_group.allow_http.id]
}

#assigne AWS public ip aka eip to internal nic

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.51"
depends_on                = aws_internet_gateway.gw
}


resource "aws_instance" "web-server" {

  #image # is not real
  ami           = "ami-imagenumber123133"
  instance_type = "t2.micro"
  availability_zone = "is-east-1a"

#enter access keyname key need to create priore 
  key_name = "web_server_key"

  network_interface {
  device_index         = 0
  network_interface_id = aws_network_interface.web-server-nic.id
 }

  user_data = <<-EOF
                #!/bin/bash
                 sudo apt update -y

                 sudo bash -c 'echo your very first web server > /var/www/html/index.html'
               EOF
 tags = {
    Name = "web-server"
 }
 }
