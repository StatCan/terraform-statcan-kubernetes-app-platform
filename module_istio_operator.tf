# Deploys the Istio Operator controller along with the IstioOperator CRD.
module "istio_operator" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-istio-operator.git?ref=v2.5.0"

  depends_on = [
    module.namespace_istio_operator_system,
    module.namespace_istio_system,
  ]

  tag = "1.10.6-distroless"

  # The following are variables that can be specified, but come with sane defaults
  namespace = module.namespace_istio_operator_system.name
  # concatenate user-specified namespaces that IstioOperator should watch
  watch_namespaces = concat([module.namespace_istio_system.name, module.namespace_ingress_general_system.name], var.istio_operator_additional_watch_namespaces)

  # Resolve Istio being oomkilled
  resources = {
    limits = {
      cpu    = "200m"
      memory = "1024Mi"
    }
    requests = {
      cpu    = "50m"
      memory = "128Mi"
    }
  }
}
