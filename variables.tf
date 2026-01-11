variable "region" {
  default = "ap-south-1"
}

variable "instance_type" {
  default = "t2.large"
}

variable "vpc_id" {
  description = "VPC ID where bastion will be deployed"
}

variable "subnet_id" {
  description = "Public subnet ID"
}

variable "allowed_ssh_cidr" {
  default = "0.0.0.0/0"
}

variable "key_name" {
  default = "bastion-host-key"
}
