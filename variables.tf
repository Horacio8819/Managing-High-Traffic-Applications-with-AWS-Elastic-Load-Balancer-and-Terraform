variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "ami_id" {
  default = "ami-0cf4768e2f1e520c5" # must match eu-central-1
}

variable "key_name" {
    default = "WebServerKeyPair"
}

variable "instance_type" {
    default = "t3.micro"
}

variable "app_port" {
  default = 3015
}

variable "desired_capacity" {
  default = 2
}

variable "max_size" {
  default = 5
}

variable "min_size" {
  default = 2
}