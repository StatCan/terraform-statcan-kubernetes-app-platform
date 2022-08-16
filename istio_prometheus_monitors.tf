resource "kubernetes_manifest" "podmonitor_monitoring_envoy_stats_monitor" {
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "PodMonitor"
    "metadata" = {
      "labels" = {
        "release" = "kube-prometheus-stack"
      }
      "name"      = "envoy-stats-monitor"
      "namespace" = "prometheus-system"
    }
    "spec" = {
      "jobLabel" = "envoy-stats"
      "namespaceSelector" = {
        "any" = true
      }
      "podMetricsEndpoints" = [
        {
          "interval" = "15s"
          "path"     = "/stats/prometheus"
          "relabelings" = [
            {
              "action" = "keep"
              "regex"  = "istio-proxy"
              "sourceLabels" = [
                "__meta_kubernetes_pod_container_name",
              ]
            },
            {
              "action" = "keep"
              "sourceLabels" = [
                "__meta_kubernetes_pod_annotationpresent_prometheus_io_scrape",
              ]
            },
            {
              "action"      = "replace"
              "regex"       = "([^:]+)(?::\\d+)?;(\\d+)"
              "replacement" = "$1:$2"
              "sourceLabels" = [
                "__address__",
                "__meta_kubernetes_pod_annotation_prometheus_io_port",
              ]
              "targetLabel" = "__address__"
            },
            {
              "action" = "labeldrop"
              "regex"  = "__meta_kubernetes_pod_label_(.+)"
            },
            {
              "action" = "replace"
              "sourceLabels" = [
                "__meta_kubernetes_namespace",
              ]
              "targetLabel" = "namespace"
            },
            {
              "action" = "replace"
              "sourceLabels" = [
                "__meta_kubernetes_pod_name",
              ]
              "targetLabel" = "pod_name"
            },
          ]
        },
      ]
      "selector" = {
        "matchExpressions" = [
          {
            "key"      = "istio-prometheus-ignore"
            "operator" = "DoesNotExist"
          },
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "servicemonitor_monitoring_istio_component_monitor" {
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "ServiceMonitor"
    "metadata" = {
      "labels" = {
        "release" = "kube-prometheus-stack"
      }
      "name"      = "istio-component-monitor"
      "namespace" = "prometheus-system"
    }
    "spec" = {
      "endpoints" = [
        {
          "interval" = "15s"
          "port"     = "http-monitoring"
        },
      ]
      "jobLabel" = "istio"
      "namespaceSelector" = {
        "any" = true
      }
      "selector" = {
        "matchExpressions" = [
          {
            "key"      = "istio"
            "operator" = "In"
            "values" = [
              "pilot",
            ]
          },
        ]
      }
      "targetLabels" = [
        "app",
      ]
    }
  }
}
