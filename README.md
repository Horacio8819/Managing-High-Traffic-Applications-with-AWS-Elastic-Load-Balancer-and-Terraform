# Managing-High-Traffic-Applications-with-AWS-Elastic-Load-Balancer-and-Terraform

TThis project was focused on:
Designed and implemented a cloud-native infrastructure on AWS using Terraform to deploy a scalable Node.js application. 
Configured an Application Load Balancer for traffic distribution, an Auto Scaling Group for dynamic resource management,
and secure networking with VPC subnets and security groups. 
Ensured high availability through multi-AZ deployment and automated instance provisioning via launch templates and user data scripts.


# Deployment 

## An Application Load Balancer with a public-facing listener on port 80

#### 

#### resource "aws_lb_listener" "http"
- LB Listener listen to the traffic coming from ALB on port 80 and forward it to lb_target_group
 
## A Target Group configured for HTTP health checks

#### resource "aws_lb_target_group" "app_tg"
- configure for health check 

## An Auto Scaling Group attachment to the Target Group

#### resource "aws_autoscaling_group" "app_asg"
- ASG is attach to the the Target group and include launch template use as template for each instance.
 
## Security groups that allow inbound HTTP to the ALB and restrict direct access to instance

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

## Output values exposing the ALB DNS name

                                                                      output "alb_dns_name" {
                                                                        value = aws_lb.app_alb.dns_name
                                                                      }

#### Outputs: alb_dns_name = "node-app-alb-886000499.eu-central-1.elb.amazonaws.com"


## Real-World Improvements: Add HTTPS by using ACM certicate and listener on port 443
