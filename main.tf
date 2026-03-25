provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "all" {}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP inbound to ALB"

  ingress {
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

# EC2 Instance Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow traffic from ALB only"

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template (your Node.js bootstrap included)
resource "aws_launch_template" "app_lt" {
  name_prefix   = "node-app-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
                #!/bin/bash
                set -e

                dnf update -y
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
                dnf install -y nodejs

                mkdir -p /home/ec2-user/app
                cd /home/ec2-user/app

                cat <<EOT > app.js
                const express = require('express');
                const app = express();
                const port = 3015;

                app.get('/', (req, res) => res.send('Hello from ASG cluster!'));
                app.get('/health', (req, res) => res.status(200).send('OK'));

                app.listen(port, '0.0.0.0', () => {console.log('Server running on 3015');});
                EOT

                npm init -y
                npm install express

                chown -R ec2-user:ec2-user /home/ec2-user/app

                cat <<EOT > /etc/systemd/system/nodeapp.service
                [Unit]
                Description=Node.js App
                After=network.target

                [Service]
                Type=simple
                User=ec2-user
                WorkingDirectory=/home/ec2-user/app
                ExecStart=/usr/bin/node app.js
                Restart=always
                Environment=NODE_ENV=production

                [Install]
                WantedBy=multi-user.target
                EOT

                systemctl daemon-reload
                systemctl enable --now nodeapp
                EOF
    )
}

# Application Load Balancer

resource "aws_lb" "app_alb" {
  name               = "node-app-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_sg.id]

  subnets = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "node-app-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Auto Scaling Group (Cluster Core)

resource "aws_autoscaling_group" "app_asg" {
  name                = "node-app-asg"
  desired_capacity    = var.desired_capacity
  min_size           = var.min_size
  max_size           = var.max_size
  vpc_zone_identifier = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "node-app-instance"
    propagate_at_launch = true
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.100.0/24"
  availability_zone = "${var.aws_region}a"
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.101.0/24"
  availability_zone = "${var.aws_region}b"
}