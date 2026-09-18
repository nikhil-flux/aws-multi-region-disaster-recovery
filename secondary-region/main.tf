# 1. Provider for Secondary Region
provider "aws" {
  region = "us-west-2"
}

# Automatically find the latest Ubuntu 22.04 AMI
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

# 2. VPC & Networking
resource "aws_vpc" "secondary_vpc" {
  cidr_block           = "10.1.0.0/16" # Different CIDR from primary
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "DR-Secondary-VPC" }
}

resource "aws_subnet" "secondary_public_subnet_1" {
  vpc_id                  = aws_vpc.secondary_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true
  tags = { Name = "DR-Secondary-Public-Subnet-1" }
}

resource "aws_subnet" "secondary_public_subnet_2" {
  vpc_id                  = aws_vpc.secondary_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true
  tags = { Name = "DR-Secondary-Public-Subnet-2" }
}

resource "aws_internet_gateway" "secondary_igw" {
  vpc_id = aws_vpc.secondary_vpc.id
  tags = { Name = "DR-Secondary-IGW" }
}

resource "aws_route_table" "secondary_rt" {
  vpc_id = aws_vpc.secondary_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_igw.id
  }
  tags = { Name = "DR-Secondary-RouteTable" }
}

resource "aws_route_table_association" "secondary_rta_1" {
  subnet_id      = aws_subnet.secondary_public_subnet_1.id
  route_table_id = aws_route_table.secondary_rt.id
}

resource "aws_route_table_association" "secondary_rta_2" {
  subnet_id      = aws_subnet.secondary_public_subnet_2.id
  route_table_id = aws_route_table.secondary_rt.id
}

# 3. Security Group
resource "aws_security_group" "secondary_sg" {
  name        = "dr-secondary-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.secondary_vpc.id

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
  tags = { Name = "DR-Secondary-SG" }
}

# 4. EC2 Instance (Secondary Region)
resource "aws_instance" "secondary_web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.secondary_public_subnet_1.id
  vpc_security_group_ids = [aws_security_group.secondary_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Disaster Recovery Project - SECONDARY REGION (us-west-2) - BACKUP ACTIVE</h1>" > /var/www/html/index.html
              EOF

  tags = { Name = "DR-Secondary-WebServer" }
}

# 5. S3 Bucket (Secondary Region - Needs Versioning for Replication)
resource "aws_s3_bucket" "secondary_backup_bucket" {
  bucket = "dr-project-backup-bucket-secondary-${random_id.suffix.hex}"
  tags = { Name = "DR-Secondary-Backup-Bucket" }
}

resource "aws_s3_bucket_versioning" "secondary_versioning" {
  bucket = aws_s3_bucket.secondary_backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

# 6. Application Load Balancer (Secondary Region)
resource "aws_lb" "secondary_alb" {
  name               = "dr-secondary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.secondary_sg.id]
  subnets            = [aws_subnet.secondary_public_subnet_1.id, aws_subnet.secondary_public_subnet_2.id]
  tags = { Name = "DR-Secondary-ALB" }
}

resource "aws_lb_target_group" "secondary_tg" {
  name     = "dr-secondary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.secondary_vpc.id
}

resource "aws_lb_target_group_attachment" "secondary_tg_attach" {
  target_group_arn = aws_lb_target_group.secondary_tg.arn
  target_id        = aws_instance.secondary_web_server.id
  port             = 80
}

resource "aws_lb_listener" "secondary_listener" {
  load_balancer_arn = aws_lb.secondary_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secondary_tg.arn
  }
}