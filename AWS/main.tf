#--------AWS KEY PAIR---------------------

resource "aws_key_pair" "ec2_authn" {
	public_key = "<PASTE-YOUR-SSH-KEY-HERE>"
	key_name   = "${var.key_name}"
}

#----------RESOURCE & PROVIDER BLOCKS------

provider "aws" {
  region = "${var.aws_region}"
  shared_credentials_file = "/home/vi-hseng/.aws/credentials"
}

resource "aws_internet_gateway" "web-gateway" {
  vpc_id = "${aws_vpc.web_server.id}"tags {
    Name = "web-gateway"
  }
}

resource "aws_vpc" "web_server" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags {
    Name = "web_server"
  }
}

resource "aws_subnet" "server-subnet-1" {
  cidr_block = "${cidrsubnet(aws_vpc.web_server.cidr_block, 3, 1)}"
  vpc_id = "${aws_vpc.web_server.id}"
  availability_zone = "us-east-1a"
}


resource "aws_instance" "web_server" {
  ami           = "${var.ami[var.aws_region]}"
  instance_type = "t2.micro"
  key_name = "terra_key"
  security_groups = ["${aws_security_group.ie-sg.id}"]  
  tags = {
      Name = "Ubuntu-EC2-Server"
    }
  subnet_id = "${aws_subnet.server-subnet-1.id}"

  user_data = "${file("user_data/nginx.sh")}"
}

resource "aws_eip" "web_server" {
  instance = "${aws_instance.web_server.id}"
  vpc      = true
}

#-------SECURITY GROUPS--------

resource "aws_security_group" "ie-sg" {
  name = "web-security-group"
  vpc_id = "${aws_vpc.web_server.id}"
  ingress {
      cidr_blocks = ["0.0.0.0/0"]
      from_port = 22
      to_port = 22
      protocol = "tcp"
  }
  
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
 }
}


#------ROUTING TABLE---------

resource "aws_route_table" "web_rt" {
  vpc_id = "${aws_vpc.web_server.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.web-gateway.id}"
  }tags {
    Name = "web_rt"
  }
}

resource "aws_route_table_association" "web-sub-association" {
  subnet_id      = "${aws_subnet.server-subnet-1.id}"
  route_table_id = "${aws_route_table.web_rt.id}"
}

#------VARIABLE BLOCK---------

variable "key_name" {}
variable "aws_region" {}

variable "ami" {
  type        = "map"
  description = "The AMIs for Ubuntu to be used"

  default = {
    us-east-1 = "ami-04b9e92b5572fa0d1"
    us-east-2 = "ami-0d5d9d301c853a04a"
    us-west-1 = "ami-0dd655843c87b6930"
    us-west-2 = "ami-06d51e91cea0dac8d"
  }
}

#--------OUTPUTS BLOCK--------------

output "ip_addresses" {
  value = "${aws_eip.web_server.public_ip}"
}

