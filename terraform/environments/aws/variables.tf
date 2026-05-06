variable "aws_region" {
  default     = "us-east-1"
  description = "AWS Region to deploy resources"
}

variable "cluster_name" {
  default     = "voting-app-cluster"
  description = "EKS Cluster name"
}

variable "node_instance_type" {
  default     = "t3.medium"
  description = "EC2 instance type for EKS worker nodes"
}

variable "node_desired_size" {
  default     = 2
  description = "Desired number of worker nodes"
}

variable "node_max_size" {
  default     = 3
  description = "Maximum number of worker nodes"
}

variable "node_min_size" {
  default     = 1
  description = "Minimum number of worker nodes"
}

variable "github_repo" {
  default     = "erotonin/devsecops-voting"
  description = "GitHub repository (owner/repo)"
}

variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "public_subnets" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "List of public subnet CIDR blocks"
}

variable "private_subnets" {
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
  description = "List of private subnet CIDR blocks"
}

variable "ecr_repo_names" {
  type        = list(string)
  default     = ["voting-app-vote", "voting-app-result", "voting-app-worker"]
  description = "List of ECR repository names to create"
}
