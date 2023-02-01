resource "kubernetes_namespace" "argo_workflows_system" {
  metadata {
    name = "argo-workflows-system"

    labels = {
      "namespace.statcan.gc.ca/purpose"                = "system"
      "network.statcan.gc.ca/allow-ingress-controller" = "true"
      "istio-injection"                                = "enabled"
    }
  }
}

module "namespace_argo_workflows_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.argo_workflows_system.id
  namespace_admins = {
    users  = []
    groups = var.administrative_groups
  }

  # CI/CD
  ci_name = var.ci_service_account_name

  allowed_loadbalancers = tostring(1 * (length(var.additional_istio_ingress_gateways) + 1))
  allowed_nodeports     = tostring(9 * (length(var.additional_istio_ingress_gateways) + 1))

  # Image Pull Secret
  enable_kubernetes_secret = var.platform_image_repository_credentials_enable
  kubernetes_secret        = local.platform_image_pull_secret_name
  docker_repo              = var.platform_image_repository
  docker_username          = var.platform_image_repository_username
  docker_password          = var.platform_image_repository_password
  docker_email             = var.platform_image_repository_email
  docker_auth              = var.platform_image_repository_auth

  # Dependencies
  dependencies = []
}
