# Creating a VPC
resource "aws_vpc" "myVPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "myVPC"
  }

}
#creating Public subnet
resource "aws_subnet" "Public" {
  vpc_id                  = aws_vpc.myVPC.id
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
  cidr_block              = "10.0.1.0/24"
  tags = {
    Name = "PublicSubnet"
  }

}
#creating Private Subnet
resource "aws_subnet" "Private" {
  vpc_id                  = aws_vpc.myVPC.id
  map_public_ip_on_launch = false
  availability_zone       = "us-west-2b"
  cidr_block              = "10.0.2.0/24"

  tags = {
    Name = "PrivateSubnet"
  }

}
#Creating EC2 instance to Public subnet
resource "aws_instance" "PublicEC2" {

  ami                    = "ami-07b0c09aab6e66ee9"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websg.id]
  subnet_id              = aws_subnet.Public.id
  tags = {
    Name = "publicEC2"
  }
  user_data = <<-EOF
            #!/bin/bash
            sudo yum upgrade -y
            sudo yum install nginx -y
            sudo systemctl start nginx
            sudo systemctl enable nginx


            cat <<EOT > /usr/share/nginx/html/index.html
            <!DOCTYPE html>
            <html>
            <head>
              <title>Terraform NGINX Server1</title>
              <style>
                @keyframes colorChange {
                  0% { color: red; }
                  50% { color: green; }
                  100% { color: blue; }
                }
                h1 { animation: colorChange 2s infinite; }
              </style>
            </head>
            <body>
              <h1>Terraform Project with NGINX</h1>
            
              <p>Welcome to the NGINX server1 deployed using Terraform !</p>
            </body>
            </html>
            EOT
            EOF


}
#Creating EC2 instance for Private Subnet
resource "aws_instance" "PrivateEC2" {
  ami                    = "ami-07b0c09aab6e66ee9"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websg.id]
  subnet_id              = aws_subnet.Private.id

  tags = {
    Name = "PrivateEC2"

  }
  user_data = <<-EOF
            #!/bin/bash
            sudo yum upgrade -y
            sudo yum install nginx -y
            sudo systemctl start nginx
            sudo systemctl enable nginx


            cat <<EOT > /usr/share/nginx/html/index.html
            <!DOCTYPE html>
            <html>
            <head>
              <title>Terraform NGINX Server2</title>
              <style>
                @keyframes colorChange {
                  0% { color: red; }
                  50% { color: green; }
                  100% { color: blue; }
                }
                h1 { animation: colorChange 2s infinite; }
              </style>
            </head>
            <body>
              <h1>Terraform Project with NGINX</h1>
            
              <p>Welcome to the NGINX server2 deployed using Terraform!</p>
            </body>
            </html>
            EOT
            EOF
}
#creating internate gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.myVPC.id

  tags = {
    Name = "IGW"

  }
}
#creating NAT gateway
resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.Public.id
  tags = {
    Name = "gw NAT"
  }

  depends_on = [aws_internet_gateway.IGW]
}
#Creating Elastic IP for NAT gateway
resource "aws_eip" "eip" {
  domain = "vpc"

}

resource "aws_security_group" "websg" {
  name   = "web"
  vpc_id = aws_vpc.myVPC.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "Web-sg"
  }
}
#Creating main route table
resource "aws_route_table" "Public" {
  vpc_id = aws_vpc.myVPC.id

  tags = {
    Name = "MRT"
  }
  route {

    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id

  }

}
resource "aws_route_table" "Private" {
  vpc_id = aws_vpc.myVPC.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT.id

  }
  tags = {
    Name = "CRT"
  }
}

#Creating public route table association
resource "aws_route_table_association" "MRT" {
  route_table_id = aws_route_table.Public.id
  subnet_id      = aws_subnet.Public.id

}
resource "aws_route_table_association" "CRT" {
  route_table_id = aws_route_table.Private.id
  subnet_id      = aws_subnet.Private.id


}

resource "aws_lb" "mylb" {
  name               = "mylb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.websg.id]
  subnets            = [aws_subnet.Public.id, aws_subnet.Private.id]

  tags = {
    Name = "web"
  }
}

resource "aws_lb_target_group" "mytg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id

  health_check {
    path = "/"
    port = "traffic-port"
  }

}
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.PublicEC2.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.mytg.arn
  target_id        = aws_instance.PrivateEC2.id
  port             = 80
}

resource "aws_lb_listener" "listner" {
  load_balancer_arn = aws_lb.mylb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.mytg.arn
    type             = "forward"

  }


}

output "awsloadbalancerDNS" {
  value = aws_lb.mylb.dns_name

}
