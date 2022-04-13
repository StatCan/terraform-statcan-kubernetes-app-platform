resource "kubernetes_namespace" "istio_operator_system" {
  metadata {
    name = "istio-operator-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
      "istio-operator-managed"          = "Reconcile"
      "istio-injection"                 = "disabled"
    }
  }
}

module "namespace_istio_operator_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.istio_operator_system.id
  namespace_admins = {
    users  = []
    groups = var.administrative_groups
  }

  # CI/CD
  ci_name = var.ci_service_account_name

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
