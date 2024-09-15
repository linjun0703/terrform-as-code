aws_region = "eu-central-1"
availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
cluster_name = "my-eks-cluster"
cluster_version = "1.27"
node_groups = {
  example = {
    desired_capacity = 1
    max_capacity     = 3
    min_capacity     = 1
    instance_type    = "t3.medium"
  }
}