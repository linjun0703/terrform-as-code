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
subnet_ids = [
  "subnet-02ad1fcba40bcdea3",
  "subnet-0146fbebd46b6bc74",
  "subnet-09bd0ea86ddaec783"
]
enable_opentelemetry = true