# Deploys the ingress-istio-controller which replaces the ingress-controller functionality built into Istio.
# This is due to the fact that the in-built functionality no longer supports the use case of our General Ingress
# Gateway as of Istio 1.6.
resource "helm_release" "ingress_istio_controller" {
  name      = "ingress-istio-controller"
  namespace = module.namespace_ingress_general_system.name

  repository          = lookup(var.platform_helm_repositories, "ingress-istio-controller", "https://statcan.github.io/charts")
  repository_username = var.platform_helm_repository_username
  repository_password = var.platform_helm_repository_password

  chart   = "ingress-istio-controller"
  version = "1.0.0"

  values = [
    <<EOF
 image:
   repository: ${local.repositories.dockerhub}statcan/ingress-istio-controller
   pullPolicy: IfNotPresent
   # Overrides the image tag whose default is the chart appVersion.
   tag: "v1.1.0"
 # These values determine the settings that can be passed to the controller.
 # If values are left empty, defaults in the image will be used.
 # Please see github.com/statcan/ingress-istio-controller for defaults.
 controller:
   # The name of the gateway to attach to. Should be in the form <namespace>/<name>.
   defaultGateway: "${helm_release.istio_ingress_gateway_general.namespace}/${helm_release.istio_ingress_gateway_general.name}-${helm_release.istio_ingress_gateway_general.chart}-https"
   # The ingress class annotation to monitor (empty string to skip checking annotation).
   ingressClass: istio
 # Settings relating to the IngressClass for this controller
 ingressClass:
   # Determines if the IngressClass is deployed
   deploy: true
   # Determines if the IngressClass is set as the default in the Cluster
   # NB: If more than one IngressClass is defined as the default,
   # the admission controller will prevent the creation of new Ingresses.
   default: true
 gateway:
   # Determines if the Gateway should be deployed
   deploy: false
   # Determines if this gateway should be used as the Controllers defaultGateway.
   # Takes precedence over controller.defaultGateway
   isControllerDefault: false
   # The specification of the Gateway to be used.
   spec:
 imagePullSecrets:
   - name: "${local.platform_image_pull_secret_name}"
 EOF
  ]
}
