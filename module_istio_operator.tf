# Deploys the Istio Operator controller along with the IstioOperator CRD.
module "istio_operator" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-istio-operator.git?ref=v2.2.0"

  depends_on = [
    module.namespace_istio_operator_system,
    module.namespace_istio_system,
  ]

  tag = "1.7.8-distroless"

  # The following are variables that can be specified, but come with sane defaults
  namespace        = module.namespace_istio_operator_system.name
  watch_namespaces = [module.namespace_istio_system.name, module.namespace_ingress_general_system.name]
}
