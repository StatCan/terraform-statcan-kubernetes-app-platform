resource "kubernetes_secret" "helm_argo_controller_azure_blob_secret" {
  metadata {
    name      = "argo-workflows-azure-blob-storage"
    namespace = kubernetes_namespace.argo_controller_system.id
  }

  data = {
    root-user     = var.platform_workflows_storage_account_name
    root-password = var.platform_workflows_primary_access_key
  }
}

resource "helm_release" "helm_argo_controller" {
  name       = "argo-controller"
  chart      = "argo-controller"
  version    = "0.0.7"
  namespace  = module.namespace_argo_controller_system.name
  repository = "https://statcan.github.io/charts"

  values = [<<EOF
replicaCount: 1

image:
  repository: "${local.repositories.aaw}argo-controller"
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: "6f621aaca104adc650d6e8092b747f8e6f4f5e13"

componentsImagePullSecretName: "${local.platform_image_pull_secret_name}"

imagePullSecrets:
  - name: "${local.platform_image_pull_secret_name}"

storageAccount:
  existingSecret: "argo-workflows-azure-blob-storage"
EOF
  ]
}
