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

# 删除或注释掉这些数据源
# data "aws_subnets" "private" {
#   filter {
#     name   = "vpc-id"
#     values = [var.existing_vpc_id]
#   }
#   tags = {
#     Tier = "Private"
#   }
# }

# data "aws_subnets" "public" {
#   filter {
#     name   = "vpc-id"
#     values = [var.existing_vpc_id]
#   }
#   tags = {
#     Tier = "Public"
#   }
# }

# 添加新的数据源来获取指定的子网
data "aws_subnet" "selected" {
  for_each = toset([
    "subnet-02ad1fcba40bcdea3",
    "subnet-0146fbebd46b6bc74",
    "subnet-09bd0ea86ddaec783"
  ])
  id = each.value
}

# 修改 EKS 模块以使用现有 VPC 的信息
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.15"  # 使用最新的稳定版本

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = data.aws_vpc.existing.id
  subnet_ids = var.subnet_ids

  cluster_endpoint_public_access  = true  # 临时启用公共访问以便于调试
  cluster_endpoint_private_access = true

  enable_irsa = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  create_cluster_security_group = true
  create_node_security_group    = false  # 设置为 false，使用现有的安全组

  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
    ingress_management_machine = {
      description = "Management machine access"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["10.121.0.0/16"]  # 假设您的管理机器在 10.121.0.0/16 网段
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # 移除 egress_all 规则，因为它可能已经存在
  }

  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  eks_managed_node_groups = {
    default = {
      min_size     = var.node_groups.example.min_capacity
      max_size     = var.node_groups.example.max_capacity
      desired_size = var.node_groups.example.desired_capacity

      instance_types = [var.node_groups.example.instance_type]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = "test"
        GithubRepo  = "terraform-aws-eks"
        GithubOrg   = "terraform-aws-modules"
      }

      tags = {
        ExtraTag = "example"
      }

      iam_role_additional_policies = {
        AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }
    }
  }

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/role1"
      username = "role1"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/user1"
      username = "user1"
      groups   = ["system:masters"]
    },
  ]

  tags = {
    Environment = "test"
    Terraform   = "true"
  }

  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "*"
        }
      ]
    }
  }

  # 启用 Fargate 日志记录
  fargate_profile_defaults = {
    kubernetes_version = var.cluster_version
    logging = {
      enabled = true
      log_types = ["scheduler", "authenticator", "controllerManager"]
    }
  }
}

# 添加 KMS 密钥资源
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
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

# 在文件末尾添加以下内容

resource "helm_release" "opentelemetry_collector" {
  name       = "opentelemetry-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = "observability"
  create_namespace = true

  set {
    name  = "mode"
    value = "daemonset"
  }

  set {
    name  = "config.exporters.logging"
    value = "{}"
  }

  set {
    name  = "config.processors.batch"
    value = "{}"
  }

  set {
    name  = "config.receivers.otlp.protocols.grpc"
    value = "{}"
  }

  set {
    name  = "config.service.pipelines.logs.receivers[0]"
    value = "otlp"
  }

  set {
    name  = "config.service.pipelines.logs.processors[0]"
    value = "batch"
  }

  set {
    name  = "config.service.pipelines.logs.exporters[0]"
    value = "logging"
  }

  depends_on = [module.eks]
}