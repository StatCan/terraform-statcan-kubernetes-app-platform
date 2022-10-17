
# Deploys a Mutating Admissions Controller that changes Gateway references in VirtualServices from one to another.
# This is a requirement since Gateways are directly referenced by end-users and a deployment of a new Gateway breaks exsisting functionality.
# As part of the update to Istio 1.6, the Gateway used for our ingress gateway was no longer able to be used and required that
# a new one be deployed.
resource "helm_release" "virtualservice_gateway_renamer" {
  name      = "gateway-renamer"
  namespace = module.namespace_ingress_general_system.name

  repository          = lookup(var.platform_helm_repositories, "gateway-renamer", "https://statcan.github.io/charts")
  repository_username = var.platform_helm_repository_username
  repository_password = var.platform_helm_repository_password

  chart   = "mutating-webhook"
  version = "0.2.0"

  values = [
    <<EOF
# Default values for mutating-webhook.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

# The domain of the cluster.
# Defaults to cluster.local
clusterDomain: cluster.local

replicaCount: 2
image:
  repository: ${local.repositories.dockerhub}statcan/virtualservice-gateway-rename-mutator
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: "v1.1.0"

# Arguments to pass to the container.
arguments:
  - "-old-gateway-name=${module.namespace_istio_system.name}/istio-autogenerated-k8s-ingress"
  - "-new-gateway-name=${helm_release.istio_ingress_gateway_general.namespace}/${helm_release.istio_ingress_gateway_general.name}-${helm_release.istio_ingress_gateway_general.chart}-https"
  - "-v=3"

# Configurations around certificates.
certificates:
  # The mount path of the certificates.
  # Defaults to /certs.
  certsMountPath: /certs
  # Defines the duration of the certificates validity.
  duration: 25920h0m0s # 36 months
  # Defines the amount of time before expiry when the certificate should be renewed.
  renewBefore: 720h0m0s # 30 days

# Configurations pertaining to configuring the Webhook
webhook:
  # The API version of the AdmissionReviews to use.
  # Webhooks are required to support at least one AdmissionReview version understood by the current and previous API server.
  admissionReviewVersions: ["v1beta1", "v1"]
  # The name of the admission webhook.
  # Name should be fully qualified, e.g., imagepolicy.kubernetes.io, where
  # "imagepolicy" is the name of the webhook, and kubernetes.io is the name
  # of the organization.
  name: "virtualservice-gateway-renamer.cloud.statcan.ca"
  # A LabelSelector for Namespaces. Allows the inclusion or exclusion of Namespaces
  # for namespaced resources.
  namespaceSelector:
    # matchExpressions:
    # - key: environment
    #   operator: In
    #   values: ["prod","staging"]
  # Defines how unrecognized errors and timeout errors from the admission webhook are handled.
  # Allowed values are Ignore or Fail.
  failurePolicy: Fail
  # Defines if the webhook should work on the exact resource or equivalents that are passed to the server.
  # (in regards to version)
  matchPolicy: Equivalent
  # Defines if mutating admission plugins observe changes made by other plugins.
  # Allowed values are Never or IfNeeded.
  reinvocationPolicy: Never
  # Defines if a webhook has a side-effect. Webhooks typically operate only on the content of the AdmissionReview sent to them.
  # Allowed values are Unknown, None, Some, NoneOnDryRun.
  sideEffects: None
  # Rules describes what operations on what resources/subresources the webhook cares about.
  # Note: resources should be lowercase and their plural name.
  rules:
    - apiGroups:
      - "networking.istio.io"
      apiVersions:
      - v1beta1
      operations:
      - CREATE
      - UPDATE
      resources:
      - virtualservices
      scope: 'Namespaced'

imagePullSecrets:
 - name: "${local.platform_image_pull_secret_name}"

nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""

podAnnotations: {}

podSecurityContext: {}
  # fsGroup: 2000

securityContext: {}
  # capabilities:
  #   drop:
  #   - ALL
  # readOnlyRootFilesystem: true
  # runAsNonRoot: true
  # runAsUser: 1000

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 3
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80

resources:
  # We usually recommend not to specify default resources and to leave this as a conscious
  # choice for the user. This also increases chances charts run on environments with little
  # resources, such as Minikube. If you do want to specify resources, uncomment the following
  # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  limits:
    cpu: 20m
    memory: 64Mi
  requests:
    cpu: 10m
    memory: 32Mi

nodeSelector: {}

tolerations: []

affinity: {}
EOF
  ]
}
