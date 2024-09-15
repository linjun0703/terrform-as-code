terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# 移除原有的 VPC 模块
# module "vpc" { ... }

# 添加数据源来获取现有 VPC 的信息
data "aws_vpc" "existing" {
  id = var.existing_vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
  tags = {
    Tier = "Private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
  tags = {
    Tier = "Public"
  }
}

# 修改 EKS 模块以使用现有 VPC 的信息
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = data.aws_vpc.existing.id
  subnet_ids      = data.aws_subnets.all.ids
  control_plane_subnet_ids = data.aws_subnets.all.ids  # 如果需要的话
  node_groups     = var.node_groups
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "alb_ingress" {
  source = "./modules/alb_ingress"

  cluster_name = module.eks.cluster_name

  depends_on = [module.eks]
}

module "argocd" {
  source = "./modules/argocd"

  eks_cluster_name = module.eks.cluster_name
  namespace        = var.argocd_namespace

  depends_on = [module.eks]
}

module "jenkins" {
  source = "./modules/jenkins"

  eks_cluster_name = module.eks.cluster_name
  namespace        = var.jenkins_namespace

  depends_on = [module.eks]
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [var.existing_vpc_id]
  }
}