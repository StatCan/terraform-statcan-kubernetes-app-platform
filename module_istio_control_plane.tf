# This file defines the configuration for the Istio Control Plane. The following is included in this file:
# - Deployment of the Control Plane via the IstioOperator CRD
# - Enabling of STRICT mTLS between pods on the mesh
# - Preventing communication to and from pods on the mesh and those which are not, unless explicitly configured
# - Explicitly allow all pods on the mesh access to the API server since it is not on the mesh
# - Deploy a few ingresses for the telemetry services

# This module deploys the IstioOperator resource which the Istio Operator controller watches and acts upon.
module "istio_operator_istio" {
  source = "git::https://github.com/canada-ca-terraform-modules/terraform-kubernetes-istio-operator-cr.git?ref=v1.0.0"

  name      = "istio"
  namespace = module.namespace_istio_system.name

  spec = <<EOF
components:
  cni:
    enabled: true
    tag: ${module.istio_operator.tag}
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
    namespace: kube-system
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
        maxReplicas: 5
        minReplicas: 3
meshConfig:
  enableAutoMtls: true
  ingressControllerMode: 'OFF'
  enableTracing: ${var.meshconfig_enable_tracing}
  defaultConfig:
    tracing:
      zipkin:
        address: ${var.meshconfig_zipkin_address}
profile: default
values:
  global:
    proxy:
      holdApplicationUntilProxyStarts: true
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
