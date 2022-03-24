resource "kubernetes_namespace" "istio_operator_system" {
  metadata {
    name = "istio-operator-system"

    labels = {
      "namespace.statcan.gc.ca/purpose" = "system"
      "istio-operator-managed"          = "Reconcile"
      "istio-injection"                 = "disabled"
    }
  }
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"

    annotations = {
      "install.operator.istio.io/chart-owner" = "Base"
    }

    labels = {
      "namespace.statcan.gc.ca/purpose"       = "system"
      "istio-operator-managed"                = "Reconcile"
      "istio-injection"                       = "disabled"
      "install.operator.istio.io/owner-name"  = "istio"
      "install.operator.istio.io/owner-kind"  = "IstioOperator"
      "install.operator.istio.io/owner-group" = "install.istio.io"
    }
  }
}

module "namespace_istio_operator_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.istio_operator_system.id
  namespace_admins = {
    users  = []
    groups = var.administrative_groups
  }

  # CI/CD
  ci_name = var.ci_service_account_name

  # Image Pull Secret
  enable_kubernetes_secret = var.platform_image_repository_credentials_enable
  kubernetes_secret        = local.platform_image_pull_secret_name
  docker_repo              = var.platform_image_repository
  docker_username          = var.platform_image_repository_username
  docker_password          = var.platform_image_repository_password
  docker_email             = var.platform_image_repository_email
  docker_auth              = var.platform_image_repository_auth

  # Dependencies
  dependencies = []
}

module "namespace_istio_system" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-namespace.git?ref=v2.2.0"

  name = kubernetes_namespace.istio_system.id
  namespace_admins = {
    users  = []
    groups = var.administrative_groups
  }

  # CI/CD
  ci_name = var.ci_service_account_name

  allowed_loadbalancers = tostring(1 * (length(var.additional_istio_ingress_gateways) + 1))
  allowed_nodeports     = tostring(9 * (length(var.additional_istio_ingress_gateways) + 1))

  # Image Pull Secret
  enable_kubernetes_secret = var.platform_image_repository_credentials_enable
  kubernetes_secret        = local.platform_image_pull_secret_name
  docker_repo              = var.platform_image_repository
  docker_username          = var.platform_image_repository_username
  docker_password          = var.platform_image_repository_password
  docker_email             = var.platform_image_repository_email
  docker_auth              = var.platform_image_repository_auth

  # Dependencies
  dependencies = []
}

module "wildcard_certificate" {
  source = "git::https://github.com/statcan/terraform-kubernetes-cert-manager-certificate.git?ref=v1.0.1"

  name      = "wildcard"
  namespace = kubernetes_namespace.istio_system.id

  dns_names = [var.ingress_domain, "*.${var.ingress_domain}"]

  issuer = {
    name = "issuer-letsencrypt"
    kind = "ClusterIssuer"
  }

  labels = {
    "use-azuredns-solver" = "true"
  }
}

module "istio_operator" {
  source = "git::https://github.com/statcan/terraform-kubernetes-istio-operator.git?ref=restructure"

  depends_on = [
    kubernetes_namespace.istio_operator_system
  ]

  istio_namespace = kubernetes_namespace.istio_system.id
  hub             = "${local.repositories.dockerhub}istio"
  namespace       = kubernetes_namespace.istio_operator_system.id
  tag             = "1.5.10"

  iop_spec = <<EOF
addonComponents:
  grafana:
    enabled: true
    k8s:
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
  kiali:
    enabled: true
    k8s:
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
  prometheus:
    enabled: true
    k8s:
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
components:
  cni:
    enabled: true
    namespace: kube-system
    k8s:
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: node.statcan.gc.ca/purpose
        operator: Exists
      - key: node.statcan.gc.ca/use
        operator: Exists
      - key: data.statcan.gc.ca/classification
        operator: Exists
  ingressGateways:
    - enabled: true
      k8s:
        serviceAnnotations:
          service.beta.kubernetes.io/azure-load-balancer-internal: 'true'
%{if var.load_balancer_subnet != null}
          service.beta.kubernetes.io/azure-load-balancer-internal-subnet: '${var.load_balancer_subnet}'
%{endif}
        tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
        hpaSpec:
          maxReplicas: 5
          metrics:
            - resource:
                name: cpu
                targetAverageUtilization: 80
              type: Resource
          minReplicas: 3
        overlays:
          - kind: Service
            name: istio-ingressgateway
            patches:
              - path: spec.externalTrafficPolicy
                value: Local
          - apiVersion: networking.istio.io/v1beta1
            kind: Gateway
            name: ingressgateway
            patches:
              - path: metadata.name
                value: istio-autogenerated-k8s-ingress
              - path: 'spec.servers[0]'
                value:
                  hosts:
                    - '*.${var.ingress_domain}'
                  port:
                    name: http
                    number: 80
                    protocol: HTTP2
                  tls:
                    httpsRedirect: true
              - path: 'spec.servers[1]'
                value:
                  hosts:
                    - '*.${var.ingress_domain}'
                  port:
                    name: https-default
                    number: 443
                    protocol: HTTPS
                  tls:
                    cipherSuites:
                      - TLS_AES_256_GCM_SHA384
                      - TLS_AES_128_GCM_SHA256
                      - ECDHE-RSA-AES256-GCM-SHA384
                      - ECDHE-RSA-AES128-GCM-SHA256
                    credentialName: wildcard-tls
                    maxProtocolVersion: TLSV1_2
                    minProtocolVersion: TLSV1_2
                    mode: SIMPLE
                    privateKey: sds
                    serverCertificate: sds
%{for gateway in var.additional_istio_ingress_gateways}
    - enabled: true
      name: istio-ingressgateway-${gateway.name}
      k8s:
        serviceAnnotations:
          service.beta.kubernetes.io/azure-load-balancer-internal: 'true'
%{if var.load_balancer_subnet != null}
          service.beta.kubernetes.io/azure-load-balancer-internal-subnet: '${var.load_balancer_subnet}'
%{endif}
        tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
        hpaSpec:
          maxReplicas: 5
          metrics:
            - resource:
                name: cpu
                targetAverageUtilization: 80
              type: Resource
          minReplicas: 3
          scaleTargetRef:
            apiVersion: apps/v1
            kind: Deployment
            name: ingressgateway-${gateway.name}
        overlays:
          - apiVersion: policy/v1beta1
            kind: PodDisruptionBudget
            name: istio-ingressgateway-${gateway.name}
            patches:
              - path: spec.selector.matchLabels.istio
                value: ingressgateway-${gateway.name}
          - kind: HorizontalPodAutoscaler
            name: istio-ingressgateway-${gateway.name}
            patches:
              - path: metadata.labels.istio
                value: ingressgateway-${gateway.name}
              - path: spec.scaleTargetRef.name
                value: istio-ingressgateway-${gateway.name}
          - apiVersion: v1
            kind: Service
            name: istio-ingressgateway-${gateway.name}
            patches:
              - path: metadata.labels.istio
                value: ingressgateway-${gateway.name}
              - path: spec.selector.istio
                value: ingressgateway-${gateway.name}
              - path: spec.externalTrafficPolicy
                value: Local
          - kind: Deployment
            name: istio-ingressgateway-${gateway.name}
            patches:
              - path: metadata.labels.istio
                value: ingressgateway-${gateway.name}
              - path: spec.selector.matchLabels.istio
                value: ingressgateway-${gateway.name}
              - path: spec.template.metadata.labels.istio
                value: ingressgateway-${gateway.name}
          - apiVersion: networking.istio.io/v1beta1
            kind: Gateway
            name: istio-ingressgateway-${gateway.name}
            patches:
              - path: metadata.name
                value: ${gateway.name}-gateway
              - path: metadata.namespace
                value: ${gateway.name}
              - path: spec.selector
                value:
                  istio: ingressgateway-${gateway.name}
              - path: 'spec.servers[0]'
                value:
                  hosts: ${jsonencode(gateway.hosts)}
                  port:
                    name: http
                    number: 80
                    protocol: HTTP2
                  tls:
                    httpsRedirect: true
              - path: 'spec.servers[1]'
                value:
                  hosts: ${jsonencode(gateway.hosts)}
                  port:
                    name: https-${gateway.name}
                    number: 443
                    protocol: HTTPS
                  tls:
                    cipherSuites:
                      - TLS_AES_256_GCM_SHA384
                      - TLS_AES_128_GCM_SHA256
                      - ECDHE-RSA-AES256-GCM-SHA384
                      - ECDHE-RSA-AES128-GCM-SHA256
                    credentialName: ${gateway.certificate_secret_name}
                    maxProtocolVersion: TLSV1_2
                    minProtocolVersion: TLSV1_2
                    mode: SIMPLE
                    privateKey: sds
                    serverCertificate: sds
%{endfor}
        strategy:
          rollingUpdate:
            maxSurge: 100%
            maxUnavailable: 25%
  policy:
    enabled: true
    k8s:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      hpaSpec:
        minReplicas: 3
        maxReplicas: 5
  telemetry:
    enabled: true
    k8s:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      hpaSpec:
        minReplicas: 3
        maxReplicas: 5
  pilot:
    enabled: true
    k8s:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      env:
        - name: PILOT_HTTP10
          value: 'true'
      hpaSpec:
        minReplicas: 3
        maxReplicas: 5
meshConfig:
  disablePolicyChecks: false
  enableAutoMtls: true
profile: default
values:
  gateways:
    istio-ingressgateway:
      k8sIngress: false
      k8sIngressHttps: false
      sds:
        enabled: true
  global:
    controlPlaneSecurityEnabled: false
    disablePolicyChecks: false
    enableTracing: false
    k8sIngress:
      enableHttps: false
      enabled: false
    mtls:
      auto: true
      enabled: true
    policyCheckFailOpen: false
    outboundTrafficPolicy:
      mode: ALLOW_ANY
    sds:
      enabled: true
  grafana:
    contextPath: /
    enabled: true
    ingress:
      annotations:
        kubernetes.io/ingress.class: istio
      enabled: true
      hosts:
        - istio-grafana.${var.ingress_domain}
  kiali:
    contextPath: /
    dashboard:
      auth:
        strategy: login
      grafanaURL: https://istio-grafana.${var.ingress_domain}
      secretName: kiali
      viewOnlyMode: true
    enabled: true
    ingress:
      annotations:
        kubernetes.io/ingress.class: istio
      enabled: true
      hosts:
        - istio-kiali.${var.ingress_domain}
  pilot:
    enableProtocolSniffingForInbound: false
    enableProtocolSniffingForOutbound: false
  sidecarInjectorWebhook:
    rewriteAppHTTPProbe: true
EOF
}
