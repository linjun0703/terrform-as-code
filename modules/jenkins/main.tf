resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  set {
    name  = "controller.serviceType"
    value = "LoadBalancer"
  }

  wait = true
  wait_for_jobs = true

  timeout = 600 # 10 minutes
}