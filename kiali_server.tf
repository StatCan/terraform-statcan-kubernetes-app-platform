resource "kubernetes_manifest" "kiali_server" {
  manifest = {
    "apiVersion" = "kiali.io/v1alpha1"
    "kind"       = "Kiali"
    "metadata" = {
      "name"      = "kiali"
      "namespace" = "kiali-system"
      "finalizers" = [
        "finalizer.kiali",
      ]
    }
    "spec" = {
      "deployment" = {
        "accessible_namespaces" = [
          "**",
        ]
        "image_name" = "${local.repositories.quay}kiali/kiali"
        "image_pull_secrets" = [
          "${local.platform_image_pull_secret_name}",
        ]
        "image_version" = "v1.37.0"
        "ingress" = {
          "class_name" = "ingress-istio-controller"
          "enabled"    = true
        }
        "override_ingress_yaml" = {
          "spec" = {
            "rules" = [
              {
                "host" = "kiali.${var.ingress_domain}"
                "http" = {
                  "paths" = [
                    {
                      "backend" = {
                        "serviceName" = "kiali"
                        "servicePort" = 20001
                      }
                      "path" = "/.*"
                      "pathType" = "ImplementationSpecific"
                    },
                  ]
                }
              },
            ]
          }
        }
      }
      "external_services" = {
        "grafana" = {
          "in_cluster_url" = "http://prometheus-operator-grafana.prometheus-system:80"
        }
        "istio" = {
          "component_status" = {
            "components" = [
              {
                "app_label" = "istiod"
                "is_core"   = true
                "namespace" = "istio-system"
              },
              {
                "app_label" = "istio-ingressgateway"
                "is_core"   = true
                "namespace" = "ingress-general-system"
              },
            ]
            "enabled" = true
          }
          "url_service_version" = "http://istiod.istio-system:15010/version"
        }
        "prometheus" = {
          "url" = "http://prometheus-operator-prometheus.prometheus-system:9090"
        }
        "tracing" = {
          "enabled" = false
        }
      }
      "istio_component_namespaces" = {
        "grafana"    = "prometheus-system"
        "istiod"     = "istio-system"
        "pilot"      = "istio-system"
        "prometheus" = "prometheus-system"
        "tracing"    = "prometheus-system"
      }
      "istio_namespace" = "istio-system"
      "server" = {
        "web_fqdn" = "kiali.${var.ingress_domain}"
      }
    }
  }

  computed_fields = ["metadata.finalizers"]
}

resource "kubernetes_manifest" "destinationrule_kiali_system" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1alpha3"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = "kiali"
      "namespace" = "kiali-system"
    }
    "spec" = {
      "host" = "kiali.kiali-system.svc.cluster.local"
      "trafficPolicy" = {
        "tls" = {
          "mode" = "DISABLE"
        }
      }
    }
  }
}
