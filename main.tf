terraform {
	required_providers {
		aws = {
			source  = "hashicorp/aws"
			version = "~> 5.0"
		}
	}
}

variable "aws_region" {
	description = "AWS region in which to create the instance."
	type        = string
	default     = "us-east-1"
}

provider "aws" {
	region = var.aws_region
}

data "aws_vpc" "default" {
	default = true
}

data "aws_subnets" "default" {
	filter {
		name   = "vpc-id"
		values = [data.aws_vpc.default.id]
	}
}

data "aws_ssm_parameter" "al2023_ami" {
	name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "nginx" {
	name_prefix = "nginx-"
	description = "Allow inbound HTTP traffic"
	vpc_id      = data.aws_vpc.default.id

	ingress {
		description = "HTTP"
		from_port   = 80
		to_port     = 80
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

resource "aws_instance" "nginx" {
	ami                         = data.aws_ssm_parameter.al2023_ami.value
	instance_type               = "t3.micro"
	subnet_id                   = data.aws_subnets.default.ids[0]
	vpc_security_group_ids      = [aws_security_group.nginx.id]
	associate_public_ip_address = true
	user_data_replace_on_change = true

	root_block_device {
		volume_size           = 30
		volume_type           = "gp3"
		delete_on_termination = true
	}

	user_data = <<-EOF
		#!/bin/bash
		dnf install -y nginx
		cat > /usr/share/nginx/html/index.html <<'HTML'
		<!doctype html>
		<html lang="en">
		<head>
		  <meta charset="utf-8">
		  <meta name="viewport" content="width=device-width, initial-scale=1">
		  <title>DevOps Learning</title>
		  <style>
		    :root { color-scheme: light; font-family: system-ui, sans-serif; }
		    * { box-sizing: border-box; }
		    body { min-height: 100vh; margin: 0; display: grid; place-items: center; padding: 24px; background: #edf3f2; color: #18312e; }
		    main { width: min(100%, 620px); padding: 40px; border-top: 6px solid #e27a45; background: #fff; box-shadow: 0 18px 50px #18312e18; }
		    p { line-height: 1.6; }
		    .status { display: inline-flex; align-items: center; gap: 9px; margin-top: 18px; padding: 9px 12px; background: #e8f4eb; color: #21633a; font-size: 0.9rem; font-weight: 700; }
		    .dot { width: 9px; height: 9px; border-radius: 50%; background: #319653; }
		    @media (max-width: 480px) { main { padding: 28px 22px; } }
		  </style>
		</head>
		<body>
		  <main>
		    <p>DEVOPS LEARNING / SAMPLE APP</p>
		    <h1>Your app is live.</h1>
		    <p>This page is being served by Nginx on an EC2 instance provisioned with Terraform.</p>
		    <div class="status"><span class="dot"></span>Nginx is running</div>
		  </main>
		</body>
		</html>
		HTML
		systemctl enable --now nginx
	EOF

	tags = {
		Name = "nginx-server"
	}
}

output "nginx_url" {
	description = "Public URL for the Nginx server."
	value       = "http://${aws_instance.nginx.public_ip}"
}
