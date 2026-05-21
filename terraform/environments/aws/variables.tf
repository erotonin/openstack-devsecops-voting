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

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
  description = "EC2 instance types for EKS worker nodes"
}

variable "node_desired_size" {
  default     = 3
  description = "Desired number of worker nodes"
}

variable "node_max_size" {
  default     = 3
  description = "Maximum number of worker nodes"
}

variable "node_min_size" {
  default     = 2
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

variable "database_subnets" {
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
  description = "List of isolated database subnet CIDR blocks"
}

variable "ecr_repo_names" {
  type        = list(string)
  default     = ["voting-app-vote", "voting-app-result", "voting-app-worker"]
  description = "List of ECR repository names to create"
}

variable "gitops_repo_url" {
  type        = string
  default     = "https://github.com/erotonin/devsecops-voting.git"
  description = "Git repository URL used by ArgoCD"
}

variable "gitops_target_revision" {
  type        = string
  default     = "main"
  description = "Git revision tracked by ArgoCD"
}

variable "argocd_domain" {
  type        = string
  default     = "argocd.local"
  description = "ArgoCD external domain, used when ingress is enabled"
}

variable "enable_observability" {
  type        = bool
  default     = true
  description = "Install Prometheus/Grafana and Loki/Promtail"
}

variable "enable_runtime_security" {
  type        = bool
  default     = true
  description = "Install Falco runtime detection stack"
}

variable "enable_image_signature_policy" {
  type        = bool
  default     = true
  description = "Install Sigstore policy-controller for image signature policy"
}

variable "falco_webhook_url" {
  type        = string
  default     = ""
  description = "Optional Falcosidekick webhook URL for alert forwarding"
}

variable "name_prefix" {
  type        = string
  default     = "devsecops-voting"
  description = "Common resource name prefix"
}

variable "environment" {
  type        = string
  default     = "full-demo"
  description = "Deployment environment label"
}

variable "azure_bgp_asn" {
  type        = number
  default     = 65000
  description = "Azure VPN Gateway BGP ASN"
}

variable "enable_aks_spoke_registration" {
  type        = bool
  default     = false
  description = "Register AKS as a spoke cluster in the AWS ArgoCD hub. Disabled by default because AKS has its own standby ArgoCD."
}
