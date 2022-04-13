# This file defines the configuration for the Istio Control Plane. The following is included in this file:
# - Deployment of the Control Plane via the IstioOperator CRD
# - Enabling of STRICT mTLS between pods on the mesh
# - Preventing communication to and from pods on the mesh and those which are not, unless explicitly configured
# - Explicitly allow all pods on the mesh access to the API server since it is not on the mesh
# - Deploy a few ingresses for the telemetry services

# This module deploys the IstioOperator resource which the Istio Operator controller watches and acts upon.
module "istio_operator_istio" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-istio-operator-cr?ref=v1.0.0"

  name      = "istio"
  namespace = module.namespace_istio_system.name

  spec = <<EOF
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
    tag: ${module.istio_operator.tag}
    namespace: "kube-system"
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
    - enabled: false
      name: istio-ingressgateway
  pilot:
    enabled: true
    tag: ${module.istio_operator.tag}
    k8s:
      env:
        - name: PILOT_HTTP10
          value: 'true'
      hpaSpec:
        minReplicas: 3
        maxReplicas: 5
  policy:
    enabled: true
    tag: ${module.istio_operator.tag}
    k8s:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      hpaSpec:
        minReplicas: 3
        maxReplicas: 5
  telemetry:
    enabled: true
    tag: ${module.istio_operator.tag}
    k8s:
      tolerations:
        - key: CriticalAddonsOnly
          operator: Exists
      hpaSpec:
        minReplicas: 3
        maxReplicas: 5
meshConfig:
  disablePolicyChecks: false
  enableAutoMtls: true
  ingressControllerMode: "OFF"
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
      secretName: ${kubernetes_secret.kiali.metadata[0].name}
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

# A PeerAuthentication which enforces mTLS between Pods on the Mesh.
resource "kubernetes_manifest" "istio_peerauthentication_mtls_strict" {
  manifest = {
    "apiVersion" = "security.istio.io/v1beta1"
    "kind"       = "PeerAuthentication"
    "metadata" = {
      "name"      = "mtls-strict"
      "namespace" = module.namespace_istio_system.name
    }
    "spec" = {
      "mtls" = {
        "mode" = "STRICT"
      }
    }
  }
}

# A DestinationRule which enforces mTLS for all downstream communication for Pods on the mesh.
# This means that Pods on the Mesh will not be able to communicate with pods which aren't on
# the Mesh unless a DestinationRule is expressly created to allow for such a connection.
resource "kubernetes_manifest" "destinationrule_mtls_downstream" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = "mtls-downstream"
      "namespace" = "istio-system"
    }
    "spec" = {
      "host" = "*.local"
      "trafficPolicy" = {
        "tls" = {
          "mode" = "ISTIO_MUTUAL"
        }
      }
    }
  }
}

# A DestinationRule which allows for Pods on the Mesh to connect to the API server.
resource "kubernetes_manifest" "destinationrule_api_server" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = "api-server"
      "namespace" = module.namespace_istio_system.name
    }
    "spec" = {
      "host" = "kubernetes.default.svc.cluster.local"
      "trafficPolicy" = {
        "tls" = {
          "mode" = "DISABLE"
        }
      }
    }
  }
}

# A DestinationRule which allows for Pods on the Mesh to connect to the kube-dns service.
resource "kubernetes_manifest" "destinationrule_kube_dns" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = "kube-dns"
      "namespace" = module.namespace_istio_system.name
    }
    "spec" = {
      "host" = "kube-dns.kube-system.svc.cluster.local"
      "trafficPolicy" = {
        "tls" = {
          "mode" = "DISABLE"
        }
      }
    }
  }
}

# A DestinationRule which allows for Pods on the Mesh to connect to the Grafana service.
resource "kubernetes_manifest" "destinationrule_istio_grafana" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = "grafana"
      "namespace" = module.namespace_istio_system.name
    }
    "spec" = {
      "host" = "grafana.istio-system.svc.cluster.local"
      "trafficPolicy" = {
        "tls" = {
          "mode" = "DISABLE"
        }
      }
    }
  }
}

# An Ingress for Istio's Grafana instance.
resource "kubernetes_ingress" "istio_grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.istio_system.metadata.0.name
  }

  spec {
    ingress_class_name = "ingress-istio-controller"

    rule {
      host = "istio-grafana.${var.ingress_domain}"
      http {
        path {
          path = "/*"
          backend {
            service_name = "grafana"
            service_port = "3000"
          }
        }
      }
    }
  }
}

# A DestinationRule which allows for Pods on the Mesh to connect to the Kiali service.
resource "kubernetes_manifest" "destinationrule_istio_kiali" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = "kiali"
      "namespace" = module.namespace_istio_system.name
    }
    "spec" = {
      "host" = "kiali.istio-system.svc.cluster.local"
      "trafficPolicy" = {
        "tls" = {
          "mode" = "DISABLE"
        }
      }
    }
  }
}

# An Ingress for Istio's Kiali instance.
resource "kubernetes_ingress" "istio_kiali" {
  metadata {
    name      = "kiali"
    namespace = kubernetes_namespace.istio_system.metadata.0.name
  }

  spec {
    ingress_class_name = "ingress-istio-controller"

    rule {
      host = "istio-kiali.${var.ingress_domain}"
      http {
        path {
          path = "/*"
          backend {
            service_name = "kiali"
            service_port = "20001"
          }
        }
      }
    }
  }
}

# A secret for the Kiali login.
resource "kubernetes_secret" "kiali" {
  metadata {
    name      = "kiali"
    namespace = kubernetes_namespace.istio_system.metadata.0.name
  }

  data = {
    username   = "admin"
    passphrase = "admin"
  }

  type = "kubernetes.io/opaque"
}
