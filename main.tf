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
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = data.aws_vpc.existing.id
  subnet_ids = data.aws_subnets.private.ids  # 只使用私有子网

  cluster_endpoint_public_access  = false # 禁用公共访问
  cluster_endpoint_private_access = true  # 启用私有访问

  # 删除 cluster_endpoint_public_access_cidrs 配置

  # 保留其他安全配置
  create_cluster_security_group = true
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # 保留集群加密配置
  cluster_encryption_config = [{
    provider_key_arn = "arn:aws:kms:YOUR_REGION:YOUR_ACCOUNT_ID:key/YOUR_KMS_KEY_ID"
    resources        = ["secrets"]
  }]

  eks_managed_node_groups = var.node_groups
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

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 3.0"

#   name = "${var.cluster_name}-vpc"
#   cidr = var.vpc_cidr

#   azs             = var.availability_zones
#   private_subnets = var.vpc_private_subnets
#   public_subnets  = var.vpc_public_subnets

#   enable_nat_gateway   = true
#   single_nat_gateway   = true
#   enable_dns_hostnames = true
# }

# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "~> 19.0"

#   cluster_name    = var.cluster_name
#   cluster_version = var.cluster_version

#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.private_subnets

#   eks_managed_node_groups = var.node_groups
# }