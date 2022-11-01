module "helm_kiali_operator" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-kiali-operator.git?ref=v0.0.1"

  chart_version = "1.50.0"
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
  pullSecrets:
    - "${local.platform_image_pull_secret_name}"

# Set to true if you want to allow the operator to only be able to install Kiali in view-only-mode.
# The purpose for this setting is to allow you to restrict the permissions given to the operator itself.
onlyViewOnlyMode: true

# allowAdHocKialiImage tells the operator to allow a user to be able to install a custom Kiali image as opposed
# to the image the operator will install by default. In other words, it will allow the
# Kiali CR spec.deployment.image_name and spec.deployment.image_version to be configured by the user.
# You may want to disable this if you do not want users to install their own Kiali images.
allowAdHocKialiImage: true
EOF
}
