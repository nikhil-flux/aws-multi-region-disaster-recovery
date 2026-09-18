**🎯 Project Overview**
	
	This project demonstrates a multi-region disaster recovery (DR) setup on AWS with infrastructure-as-code using Terraform. It creates a highly available web 			application that spans two geographic regions (us-east-1 and us-west-2), ensuring business continuity if one region fails.
*Key Features*

	•	✅ Two independent regions with identical infrastructure
	•	✅ Automatic failover detection via health check script
	•	✅ Data replication across regions using S3
	•	✅ Infrastructure as Code (Terraform)
	•	✅ Load balancing within each region
	•	✅ Multi-AZ redundancy within each region

*DR Strategy: Cold Standby*

	This project implements a cold standby disaster recovery pattern:
		•	Primary Region (us-east-1): Actively serving production traffic
		•	Secondary Region (us-west-2): Idle, ready to take over if primary fails
		•	RTO (Recovery Time Objective): ~5-10 minutes (manual failover)
		•	RPO (Recovery Point Objective): ~minutes (depends on data sync interval)

**🏗️ Architecture**

	┌─────────────────────────────────┐       ┌─────────────────────────────────┐
	│     PRIMARY REGION (us-east-1)  │       │   SECONDARY REGION (us-west-2)  │
	│                                 │       │                                 │
	│  ┌─────────────────────────────┐│       │┌─────────────────────────────┐  │
	│  │   VPC: 10.0.0.0/16          ││       ││   VPC: 10.1.0.0/16          │  │
	│  │                             ││       ││                             │  │
	│  │  ┌──────────┐  ┌──────────┐ ││       ││ ┌──────────┐  ┌──────────┐  │  │
	│  │  │ Subnet   │  │ Subnet   │ ││       ││ │ Subnet   │  │ Subnet   │  │  │
	│  │  │ 1a       │  │ 1b       │ ││       ││ │ 1a       │  │ 1b       │  │  │
	│  │  │ 10.0.1   │  │ 10.0.2   │ ││       ││ │ 10.1.1   │  │ 10.1.2   │  │  │
	│  │  └────┬─────┘  └────┬─────┘ ││       ││ └────┬─────┘  └────┬─────┘  │  │
	│  │       │              │      ││       ││      │             │        │  │
	│  │    ┌──▼──┐        ┌──▼──┐   ││       ││   ┌──▼──┐       ┌──▼──┐     │  │
	│  │    │ EC2 │        │ EC2 │   ││       ││   │ EC2 │       │ EC2 │     │  │
	│  │    │     │        │     │   ││       ││   │     │       │     │     │  │
	│  │    └──▲──┘        └──▲──┘   ││       ││   └──▲──┘       └──▲──┘     │  │
	│  │       └────────┬─────┘      ││       ││      └────────┬─────┘       │  │
	│  │                │            ││       ││             │               │  │
	│  │          ┌─────▼──────┐     ││       ││       ┌─────▼──────┐        │  │
	│  │          │    ALB     │     ││       ││       │    ALB     │        │  │
	│  │          │ Port 80    │     ││       ││       │ Port 80    │        │  │
	│  │          └─────┬──────┘     ││       ││       └─────┬──────┘        │  │
	│  │                │            ││       ││             │               │  │
	│  │          ┌─────▼──────┐     ││       ││       ┌─────▼──────┐        │  │
	│  │          │  S3 Bucket │     ││       ││       │  S3 Bucket │        │  │
	│  │          │ (Versioned)│     ││       ││       │ (Versioned)│        │  │
	│  │          └────────────┘     ││       ││       └────────────┘        │  │
	│  └─────────────────────────────┘│       │└─────────────────────────────┘  │
	└─────────────────────────────────┘       └─────────────────────────────────┘
           │                                          │
           └──────────────────┬───────────────────────┘
                              │
                     ┌────────▼────────┐
                     │ Health Check    │
                     │ Script (Python) │
                     │ Monitors Primary│
                     │ Triggers        │
                     │ Failover        │
                     └─────────────────┘

**🔧 Components Explained**

	1. VPC (Virtual Private Cloud)
	Each region has its own isolated network with:
	•	CIDR Block: 10.0.0.0/16 (primary) | 10.1.0.0/16 (secondary)
	•	Subnets: 2 public subnets per region (one per AZ for redundancy)
	•	Internet Gateway: Enables internet access for instances
	•	Route Tables: Direct internet traffic to IGW
	2. Security Groups
	Acts as a stateful firewall at the instance level.
	Ingress Rules:

		- Port 80 (HTTP):  Open to 0.0.0.0/0 (anyone on the internet)
		- Port 22 (SSH):   Open to 0.0.0.0/0 (SECURITY RISK ⚠️)
   	Egress Rules:

		- All traffic (0.0.0.0/0) outbound allowed
		
Security Issues & Fixes:

		❌ SSH is open to the world
		✅ Fix: Restrict to bastion host CIDR or use AWS Systems Manager Session Manager

		❌ No HTTPS/TLS
		✅ Fix: Add port 443 (HTTPS) with ACM certificate

		❌ No database security group
		✅ Fix: Create separate SG for RDS allowing only EC2 SG on port 3306/5432

3. EC2 Instances (t3.micro)
	Lightweight compute instances running Nginx web server.

*User Data Script (Auto-executed on startup):*

		#!/bin/bash
		apt-get update -y                               # Update package lists
		apt-get install -y nginx                        # Install Nginx
		systemctl start nginx                           # Start Nginx service
		systemctl enable nginx                          # Auto-start on reboot
		echo "<h1>REGION: PRIMARY/SECONDARY</h1>" > /var/www/html/index.html

Production Fix:

		# Use Auto Scaling Group instead of single instances
		resource "aws_autoscaling_group" "primary_asg" {
  		desired_capacity    = 2
  		max_size            = 4
  		min_size            = 2
  		health_check_type   = "ELB"
  
  		# Automatically terminates unhealthy instances
		}

4. Application Load Balancer (ALB)

		Distributes incoming traffic across EC2 instances.

*Configuration:*

		Listener: Port 80 → Target Group
		Target Group: Forwards to EC2 instances
		Health Check: Pings /index.html every 5 seconds

What it does:

	•	Single DNS endpoint (users don’t need to know individual EC2 IPs)
	•	Distributes traffic across instances in both AZs
	•	Removes unhealthy instances from rotation
	•	Layer 7 (application layer) routing

5. S3 Buckets (Data Backup & Sync)

		Stores backups and provides cross-region replication.

*Configuration:*

	Primary Bucket (us-east-1)
		├── Versioning: ENABLED
		│   └── Keeps all previous versions of objects
		│   └── Allows recovery from accidental deletes
		└── Replication: (NOT configured yet)

	Secondary Bucket (us-west-2)
		├── Versioning: ENABLED
		└── Receives replicated data from primary   

6. Health Check Script (Python)
   
		Monitors primary region and triggers failover.

*How it works:*

	import requests
	import time

	PRIMARY_ALB = "http://dr-primary-alb-xxxx.us-east-1.elb.amazonaws.com"
	SECONDARY_ALB = "http://dr-secondary-alb-xxxx.us-west-2.elb.amazonaws.com"

	def check_health():
    	try:
        	response = requests.get(PRIMARY_ALB, timeout=5)
        	if response.status_code == 200:
            	print("✅ PRIMARY REGION IS HEALTHY")
        	else:
            	raise Exception("Bad status code")
    	except Exception as e:
        	print("❌ CRITICAL: Primary region is DOWN!")
        	print(f"⚠️ FAILOVER INITIATED")
        	print(f"🔄 Redirect traffic to: {SECONDARY_ALB}")
        	print("📧 Alert on-call engineer via Slack/PagerDuty")

**📦 Prerequisites**

	Before deploying, ensure you have:
	1.	AWS Account
		•	Credentials configured (~/.aws/credentials)
		•	Permissions for EC2, VPC, ALB, S3, IAM

	2.	Terraform (v1.0.0+)
		•	terraform --version  # Should output v1.0.0 or higher
	
	3.	AWS CLI (optional, for manual verification)
		•	aws --version
	
	4.	Python 3.8+ (for health check script)
		•	python3 --version
		•	pip install requests


		













