variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "existing_vpc_id" {
  description = "ID of the existing VPC to use"
  type        = string
  default     = "vpc-00cac4eecf499dbb3"
}

# 移除或注释掉以下变量，因为我们不再创建新的 VPC
# variable "vpc_name" { ... }
# variable "vpc_cidr" { ... }
# variable "enable_nat_gateway" { ... }
# variable "single_nat_gateway" { ... }

# 保留这些变量，因为我们仍然需要它们来获取子网信息
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

# 移除这些变量
# variable "private_subnets" { ... }
# variable "public_subnets" { ... }

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# EKS variables
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "my-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "node_groups" {
  description = "Map of EKS managed node group definitions"
  type        = any
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "jenkins_namespace" {
  description = "Kubernetes namespace for Jenkins"
  type        = string
  default     = "jenkins"
}