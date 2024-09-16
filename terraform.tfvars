aws_region = "eu-central-1"
availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
cluster_name = "my-eks-cluster"
cluster_version = "1.30"
node_groups = {
  example = {
    desired_capacity = 1
    max_capacity     = 3
    min_capacity     = 1
    instance_type    = "c5.large"
  }
}
// 删除以下行
// vpc_cidr = "10.0.0.0/16"
// vpc_private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
// vpc_public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]