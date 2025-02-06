variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "map_public_ip_on_launch" {
  description = "Associate public IPs on launch for instances in public subnets."
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ------------------------------------------------------------------------------
# BASIC CLUSTER INFO
# ------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.31"
}

# variable "control_plane_subnet_ids" {
#   description = "A list of subnet IDs for the EKS control plane."
#   type        = list(string)
# }

variable "instance_types" {
  description = "A list of instance types for the managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

