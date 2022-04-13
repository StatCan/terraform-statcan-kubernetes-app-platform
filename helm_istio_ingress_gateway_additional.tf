# Deploys Additional Ingress Gateways used by AAW in the cluster.
# This deployment configures:
#     - the Ingress Gateway
#     - an Istio Gateway for HTTPS traffic
#     - an EnvoyFilter which adds HSTS to any response without it
#     - a cert-manager Certificate which references a ClusterIssuer to request a certificate for TLS from Let's Encrypt
resource "helm_release" "istio_ingress_gateway_additional" {
  for_each = var.additional_istio_ingress_gateways

  name      = "${each.value.name}"
  namespace = module.namespace_istio_system.name

  repository          = lookup(var.platform_helm_repositories, "istio-ingress-gateway", "https://statcan.github.io/charts")
  repository_username = var.platform_helm_repository_username
  repository_password = var.platform_helm_repository_password

  chart   = "istio-ingress-gateway"
  version = "2.1.1"

  values = [<<EOF
# Sets the tag of the images to use
tag: ${module.istio_operator.tag}

# Configurations relating to the Istio Ingress Gateway to deploy.
ingressGateway:
  # The name of the ingress-gateway instance.
  # If left blank, will use the Release name.
  name:
  # Toggles if the ingress gateway is enabled or not.
  # If disabled, the Istio Operator will remove the deployment and service.
  enabled: true
  maxReplicas: 5
  minReplicas: 3
  service:
    # Defines the type of Service to deploy:
    type: LoadBalancer
    # Defines if an "internal" or "external" Azure load-balancer is deployed for the service.
    azureLoadBalancer: internal
    azureLoadBalancerSubnet: ${var.load_balancer_subnet}

# Configures HTTPS on the ingress gateway.
https:
  # Toggles HTTPS configurations on the ingress gateway.
  enabled: true
  # The hosts to which the ingress gateway should route traffic to.
  hosts: "${each.value.hosts}"
  httpsRedirect: true
  # Configures if HSTS headers should be added to all responses which do not have it.
  hsts:
    enabled: true
    # Sets the values of the header.
    # Defaults to only setting the max-age to one year.
    value: max-age=31536000
  # Configures a cert-manager Certificate for automated certificate generation.
  certificate:
    # Defines the name of the secret that will contain the certificates.
    secretName: "${each.value.certificate_secret_name}"
    # Defines list of DNS names for the certificate.
    # Note: The first entry is set as the common name.
    dnsNames: ["*.${var.ingress_domain}"]
    # Toggles if the Azure DNS solver should be used.
    useAzureDNSSolver: true
    # Defines the type of Issuer to use.
    issuerRef:
      # Can be ClusterIssuer or Issuer.
      kind: ClusterIssuer
      # The name of the Issuer to use.
      name: letsencrypt
EOF
  ]
}
