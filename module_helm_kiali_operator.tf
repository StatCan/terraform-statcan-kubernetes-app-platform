module "helm_kiali_operator" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-kiali-operator.git?ref=v0.0.1"

  chart_version = "1.37.0"
  depends_on = [
    module.namespace_kiali_system,
  ]

  helm_namespace = module.namespace_kiali_system.name

  helm_repository          = lookup(var.platform_helm_repositories, "kiali", "https://kiali.org/helm-charts")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
image:
  repo: ${local.repositories.quay}kiali/kiali-operator
  tag: v1.37.0
  pullSecrets:
    - "${local.platform_image_pull_secret_name}"

allowAdHocKialiImage: true
EOF
}
