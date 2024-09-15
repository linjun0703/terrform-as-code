output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "argocd_namespace" {
  value = var.argocd_namespace
}

output "jenkins_namespace" {
  value = var.jenkins_namespace
}

output "alb_ingress_role_arn" {
  value = module.alb_ingress.alb_ingress_role_arn
}

output "debug_alb_ingress_cluster_name" {
  value = module.alb_ingress.debug_cluster_name
}

output "aws_account_id" {
  description = "The AWS Account ID being used"
  value       = data.aws_caller_identity.current.account_id
}