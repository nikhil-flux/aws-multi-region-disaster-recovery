# 1. Provider
provider "aws" {
  region = "us-east-1"
}

# ✅ Use dynamic AMI lookup instead of hardcoded ID
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. VPC & Networking (keep your existing VPC code)
resource "aws_vpc" "primary_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "DR-Primary-VPC" }
}

resource "aws_subnet" "primary_public_subnet_1" {
  vpc_id                  = aws_vpc.primary_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "DR-Primary-Public-Subnet-1" }
}

resource "aws_subnet" "primary_public_subnet_2" {
  vpc_id                  = aws_vpc.primary_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "DR-Primary-Public-Subnet-2" }
}

resource "aws_internet_gateway" "primary_igw" {
  vpc_id = aws_vpc.primary_vpc.id
  tags = { Name = "DR-Primary-IGW" }
}

resource "aws_route_table" "primary_rt" {
  vpc_id = aws_vpc.primary_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_igw.id
  }
  tags = { Name = "DR-Primary-RouteTable" }
}

resource "aws_route_table_association" "primary_rta_1" {
  subnet_id      = aws_subnet.primary_public_subnet_1.id
  route_table_id = aws_route_table.primary_rt.id
}

resource "aws_route_table_association" "primary_rta_2" {
  subnet_id      = aws_subnet.primary_public_subnet_2.id
  route_table_id = aws_route_table.primary_rt.id
}

# 3. Security Group
resource "aws_security_group" "primary_sg" {
  name        = "dr-primary-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.primary_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
  tags = { Name = "DR-Primary-SG" }
}

# 4. EC2 Instance with CORRECT Ubuntu commands
resource "aws_instance" "primary_web_server" {
  ami                    = data.aws_ami.ubuntu.id  # ✅ Dynamic lookup
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.primary_public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.primary_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Disaster Recovery Project - PRIMARY REGION (us-east-1)</h1>" > /var/www/html/index.html
              EOF

  tags = { Name = "DR-Primary-WebServer" }
}

# 5. S3 Bucket
resource "aws_s3_bucket" "primary_backup_bucket" {
  bucket = "dr-project-backup-bucket-${random_id.suffix.hex}"
  tags = { Name = "DR-Primary-Backup-Bucket" }
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  bucket = aws_s3_bucket.primary_backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

# 6. Application Load Balancer
resource "aws_lb" "primary_alb" {
  name               = "dr-primary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.primary_sg.id]
  subnets            = [aws_subnet.primary_public_subnet_1.id, aws_subnet.primary_public_subnet_2.id]
  tags = { Name = "DR-Primary-ALB" }
}

resource "aws_lb_target_group" "primary_tg" {
  name     = "dr-primary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.primary_vpc.id
}

resource "aws_lb_target_group_attachment" "primary_tg_attach" {
  target_group_arn = aws_lb_target_group.primary_tg.arn
  target_id        = aws_instance.primary_web_server.id
  port             = 80
}

resource "aws_lb_listener" "primary_listener" {
  load_balancer_arn = aws_lb.primary_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary_tg.arn
  }
}