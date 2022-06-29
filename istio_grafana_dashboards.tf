resource "kubernetes_config_map" "istio_dashboards" {
  metadata {
    name      = "prometheus-oper-istio-dashboards"
    namespace = "prometheus-system"

    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "istio-control-plane-dashboard.json"  = file("${path.module}/config/dashboards/istio-control-plane-dashboard.json")
    "istio-mesh-dashboard.json"           = file("${path.module}/config/dashboards/istio-mesh-dashboard.json")
    "istio-service-dashboard.json"        = file("${path.module}/config/dashboards/istio-service-dashboard.json")
    "istio-wasm-extension-dashboard.json" = file("${path.module}/config/dashboards/istio-wasm-extension-dashboard.json")
    "istio-workload-dashboard.json"       = file("${path.module}/config/dashboards/istio-workload-dashboard.json")
  }
}
