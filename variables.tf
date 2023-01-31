variable "cluster_name" {
  description = "Name of the cluster"
}

variable "tenant_id" {
  description = "The directory tenant that you want to request permission from."
  default     = ""
}

variable "ci_service_account_name" {
  default     = "ci"
  description = "Name of the CI service account."
}

variable "ingress_domain" {
}

variable "administrative_groups" {
  type        = list(string)
  description = "List of groups who have administrative access to system namespaces."
}

variable "platform_image_repository_credentials_enable" {
  type    = bool
  default = false
}

variable "platform_image_bases" {
  type        = map(string)
  description = "Overwrite base image location (MUST contain a trailing slash)"

  default = {}
}

variable "platform_image_repository" {
  default = "docker.io"
}

variable "platform_image_repository_username" {
  default = ""
}

variable "platform_image_repository_password" {
  default = ""
}

variable "platform_image_repository_email" {
  default = ""
}

variable "platform_image_repository_auth" {
  default = ""
}

variable "platform_helm_repositories" {
  type    = map(string)
  default = {}
  # default = {
  #   aad_pod_identity = "https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts"
  #   gatekeeper = "https://open-policy-agent.github.io/gatekeeper/charts"
  #   prometheus = "https://statcan.github.com/charts"
  # }
}

variable "platform_helm_repository_username" {
  default = ""
}

variable "platform_helm_repository_password" {
  default = ""
}

variable "load_balancer_subnet" {
  description = "Load balancer subnet"
  default     = null
}

variable "additional_istio_ingress_gateways" {
  type = map(object({
    hosts                   = list(string)
    certificate_secret_name = string
  }))

  description = <<-EOD
  A map of objects which specify the configurations of addditional Istio Ingress Gateways to create.

  The key into the map is the name of the Ingress gateway and value is the following object:
  additional_istio_ingress_gateway {
    hosts                   : "A list of Fully Qualified Domain Names, which will also be used as the DNS Names"
    certificate_secret_name : "The name of the TLS Secret to be created by cert-manager"
  }
  EOD

  default = {}
}
variable "istio_operator_additional_watch_namespaces" {
  description = "Additional namespaces that the IstioOperator should watch."
  type        = list(string)
  default     = []
}

# Kiali

variable "kiali_grafana_configurations" {
  description = "Values for configuring Grafana integration into Kiali."
  type = object({
    in_cluster_url = string,
    url            = string,
    token          = string,
  })
  default = {
    in_cluster_url = "",
    url            = "",
    token          = "",
  }

  sensitive = true
}

variable "kiali_prometheus_url" {
  description = "The URL to the Prometheus instance that Kiali should use for metrics lookups."
  type        = string
}

# This needed to be objects instead of maps so that the kubernetes provider wouldn't complain.
variable "kiali_resources" {
  description = "The limits and requests to set on the Kiali pod."
  type = object({
    limits = optional(object({
      cpu    = optional(string, "50m"),
      memory = optional(string, "256Mi"),
      }), {
      cpu    = "50m",
      memory = "256Mi",
    }),
    requests = optional(object({
      cpu    = optional(string, "10m"),
      memory = optional(string, "128Mi"),
      }), {
      cpu    = "10m",
      memory = "128Mi",
    }),
  })
  default  = {}
  nullable = false

  validation {
    condition     = var.kiali_resources.limits != null && var.kiali_resources.requests != null
    error_message = "Limits and requests cannot be null."
  }

  validation {
    condition     = var.kiali_resources.limits.cpu != null && var.kiali_resources.limits.memory != null
    error_message = "CPU and memory limits cannot be null."
  }

  validation {
    condition     = var.kiali_resources.requests.cpu != null && var.kiali_resources.requests.memory != null
    error_message = "CPU and memory requests cannot be null."
  }
}

variable "meshconfig_zipkin_address" {
  description = "The URL to send zipkin compatible traces to"
  default     = "zipkin.istio-system:9411"
  type        = string
}

variable "meshconfig_enable_tracing" {
  description = "Flag to control generation of trace spans and request IDs."
  default     = false
  type        = bool
}

# Argo Workflows

variable "argo_workflows_client_id" {
  description = "The Client ID for Argo Workflows"
}

variable "argo_workflows_client_secret" {
  description = "The Client Secret for Argo Workflows"
}

variable "platform_workflows_storage_account_name" {
  description = "The name of the workflows storage account."
}

variable "platform_workflows_primary_access_key" {
  description = "The primary access key of the workflows storage account."
}

variable "platform_workflows_primary_blob_endpoint" {
  description = "The primary blob endpoint of the workflows storage account."
}
