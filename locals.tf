locals {
  platform_image_pull_secret_name = "platform-images"

  # Must contain trailing slash
  repositories = {
    aaw       = lookup(var.platform_image_bases, "aaw", "k8scc01covidacr.azurecr.io/")
    dockerhub = lookup(var.platform_image_bases, "dockerhub", "docker.io/")
    mcr       = lookup(var.platform_image_bases, "mcr", "mcr.microsoft.com/")
    quay      = lookup(var.platform_image_bases, "quay", "quay.io/")
    k8s       = lookup(var.platform_image_bases, "k8s", "k8s.gcr.io/")
  }
}
