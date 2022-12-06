resource "kubernetes_manifest" "kiali_server" {
  manifest = {
    "apiVersion" = "kiali.io/v1alpha1"
    "kind"       = "Kiali"
    "metadata" = {
      "name"      = "kiali"
      "namespace" = kubernetes_namespace.kiali_system.id
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
        "image_version" = "operator_version" # Use the operator's version
        "ingress" = {
          "class_name" = "ingress-istio-controller"
          "enabled"    = true
          "override_yaml" = {
            "spec" = {
              "rules" = [
                {
                  "host" = "kiali.${var.ingress_domain}"
                  "http" = {
                    "paths" = [
                      {
                        "backend" = {
                          "service" = {
                            "name" = "kiali"
                            "port" = {
                              "number" = 20001
                            }
                          }
                        }
                        "path"     = "/"
                        "pathType" = "Prefix"
                      },
                    ]
                  }
                },
              ]
            }
          }
        }
        "resources" = var.kiali_resources
        # Prevent any changes via the UI.
        "view_only_mode" = true
      }
      "external_services" = {
        "grafana" = {
          "auth" = {
            "token" = var.kiali_grafana_configurations.token != null ? var.kiali_grafana_configurations.token : ""
            "type"  = "bearer"
          }
          "in_cluster_url" = var.kiali_grafana_configurations.in_cluster_url != null ? var.kiali_grafana_configurations.in_cluster_url : ""
          "url"            = var.kiali_grafana_configurations.url != null ? var.kiali_grafana_configurations.url : ""
        }
        "istio" = {
          "component_status" = {
            "components" = [
              {
                "app_label" = "istiod"
                "is_core"   = true
                "namespace" = kubernetes_namespace.istio_system.id
              },
              {
                "app_label" = "istio-ingressgateway"
                "is_core"   = true
                "namespace" = kubernetes_namespace.istio_system.id
              },
              {
                "app_label" = "istio-ingressgateway"
                "is_core"   = true
                "namespace" = kubernetes_namespace.ingress_general_system.id
              },
            ]
            "enabled" = true
          }
          "url_service_version" = "http://istiod.${kubernetes_namespace.istio_system.id}:15014/version"
        }
        "prometheus" = {
          "url" = var.kiali_prometheus_url
        }
        "tracing" = {
          "enabled" = false
        }
      }
      "istio_namespace" = kubernetes_namespace.istio_system.id
      "server" = {
        "web_fqdn" = "kiali.${var.ingress_domain}"
      }
    }
  }
  computed_fields = ["metadata.finalizers"]
}

resource "kubernetes_manifest" "destinationrule_kiali_system" {
  manifest = {
    "apiVersion" = "networking.istio.io/v1beta1"
    "kind"       = "DestinationRule"
    "metadata" = {
      "name"      = "kiali"
      "namespace" = kubernetes_namespace.kiali_system.id
    }
    "spec" = {
      "host" = "kiali.${kubernetes_namespace.kiali_system.id}.svc.cluster.local"
      "trafficPolicy" = {
        "tls" = {
          "mode" = "DISABLE"
        }
      }
    }
  }
}
