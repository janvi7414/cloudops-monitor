variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Deployment Region"
}

variable "aws_access_key" {
  type        = string
  sensitive   = true
  description = "AWS Access Key ID"
}

variable "aws_secret_key" {
  type        = string
  sensitive   = true
  description = "AWS Secret Access Key"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Base CIDR block for VPC"
}

variable "master_instance_type" {
  type        = string
  default     = "c7i-flex.large"
  description = "Instance type for Kubernetes Control Plane"
}

variable "worker_instance_type" {
  type        = string
  default     = "t3.small"
  description = "Instance type for Kubernetes Worker Nodes"
}

variable "key_name" {
  type        = string
  default     = "cloudops-key"
  description = "Name for the generated SSH Key Pair"
}

variable "admin_cidr" {
  description = "Administrator public IP/CIDR allowed for SSH and OpenVPN"
  type        = string
}