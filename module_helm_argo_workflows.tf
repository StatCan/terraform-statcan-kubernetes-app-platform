resource "kubernetes_secret" "helm_argo_workflows_azure_blob_secret" {
  metadata {
    name      = "argo-workflows-azure-blob-storage"
    namespace = kubernetes_namespace.argo_workflows_system.id
  }

  data = {
    root-user     = var.platform_workflows_storage_account_name
    root-password = var.platform_workflows_primary_access_key
  }
}

resource "kubernetes_secret" "helm_argo_workflows_argo_server_sso_secret" {
  metadata {
    name      = "argo-server-sso"
    namespace = kubernetes_namespace.argo_workflows_system.id
  }

  data = {
    clientId     = var.argo_workflows_client_id
    clientSecret = var.argo_workflows_client_secret
  }
}

module "helm_argo_workflows" {
  source = "git::https://gitlab.k8s.cloud.statcan.ca/cloudnative/terraform/modules/terraform-kubernetes-argo-workflows.git?ref=main"

  chart_version = "0.22.0"
  depends_on = [
    kubernetes_secret.helm_argo_workflows_argo_server_sso_secret,
  ]

  helm_namespace           = module.namespace_argo_workflows_system.name
  helm_repository          = lookup(var.platform_helm_repositories, "argo-workflows", "https://argoproj.github.io/argo-helm")
  helm_repository_username = var.platform_helm_repository_username
  helm_repository_password = var.platform_helm_repository_password

  values = <<EOF
images:
  pullPolicy: Always
  pullSecrets:
    - name: "${local.platform_image_pull_secret_name}"

controller:
  image:
    registry: ${trimsuffix(local.repositories.quay, "/")}
    repository: argoproj/workflow-controller
    tag: v3.4.4
  workflowDefaults:
    spec:
      activeDeadlineSeconds: 28800
      podGC:
        strategy: OnPodCompletion

executor:
  image:
    registry: ${trimsuffix(local.repositories.quay, "/")}
    repository: argoproj/argoexec
    tag: v3.4.4

server:
  image:
    registry: ${trimsuffix(local.repositories.quay, "/")}
    repository: argoproj/argocli
    tag: v3.4.4
  extraArgs:
    - '--auth-mode=sso'
    - '--auth-mode=client'
  extraEnv:
    - name: "SSO_DELEGATE_RBAC_TO_NAMESPACE"
      value: "true"
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: istio
    hosts:
      - "argo-workflows.${var.ingress_domain}"
    https: true
  sso:
    issuer: "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
    clientId:
      name: ${kubernetes_secret.helm_argo_workflows_argo_server_sso_secret.metadata.0.name}
      key: clientId
    clientSecret:
      name: ${kubernetes_secret.helm_argo_workflows_argo_server_sso_secret.metadata.0.name}
      key: clientSecret
    redirectUrl: "https://argo-workflows.${var.ingress_domain}/oauth2/callback"
    rbac:
      enabled: true
    scopes:
      - openid
      - profile
      - email

workflow:
  serviceAccount:
    create: true
    name: "argo-workflows"
  rbac:
    create: true

useDefaultArtifactRepo: true
useStaticCredentials: true

artifactRepository:
  archiveLogs: true
  azure:
    endpoint: ${var.platform_workflows_primary_blob_endpoint}
    container: workflows
    # blob: /
    # accountKeySecret is a secret selector.
    # It references the k8s secret named 'my-azure-storage-credentials'.
    # This secret is expected to have have the key 'account-access-key',
    # containing the base64 encoded credentials to the storage account.
    #
    # If a managed identity has been assigned to the machines running the
    # workflow (e.g., https://docs.microsoft.com/en-us/azure/aks/use-managed-identity)
    # then accountKeySecret is not needed, and useSDKCreds should be
    # set to true instead:
    useSDKCreds: false
    accountKeySecret:
      name: argo-workflows-azure-blob-storage
      key: root-password
EOF
}

# Argo Workflows for Default Service Account

resource "kubernetes_service_account" "argo_workflows_default" {
  metadata {
    name      = "user-default-login"
    namespace = "argo-workflows-system"

    annotations = {
      "workflows.argoproj.io/rbac-rule"            = "true"
      "workflows.argoproj.io/rbac-rule-precedence" = "0"
    }
  }
}

resource "kubernetes_cluster_role" "argo_workflows_namespace" {
  metadata {
    name = "argo-workflows-namespace"
  }

  rule {
    api_groups = ["argoproj.io"]
    resources = [
      "eventsources",
      "eventsources/finalizers",
      "sensors",
      "sensors/finalizers",
      "workflows",
      "workflows/finalizers",
      "workfloweventbindings",
      "workfloweventbindings/finalizers",
      "workflowtemplates",
      "workflowtemplates/finalizers",
      "cronworkflows",
      "cronworkflows/finalizers",
      "clusterworkflowtemplates",
      "clusterworkflowtemplates/finalizers"
    ]
    verbs = [
      "create",
      "delete",
      "deletecollection",
      "get",
      "list",
      "patch",
      "update",
      "watch"
    ]
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    verbs          = ["get"]
    resource_names = ["argo-workflows-azure-blob-storage"]
  }
}

resource "kubernetes_cluster_role" "argo_workflows_workflow" {
  metadata {
    name = "argo-workflows-workflow"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "watch", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "watch"]
  }
}
