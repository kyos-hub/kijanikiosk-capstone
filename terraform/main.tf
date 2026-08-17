terraform {
  required_version = ">= 1.5.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

# Points at your local minikube context.
# Run `kubectl config current-context` to confirm it says "minikube" before applying.
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}

variable "staging_namespace" {
  description = "Namespace for the isolated staging environment"
  type        = string
  default     = "kijani-staging"
}

variable "environment_label" {
  description = "Label applied to the namespace for identification"
  type        = string
  default     = "staging"
}

resource "kubernetes_namespace" "staging" {
  metadata {
    name = var.staging_namespace

    labels = {
      environment = var.environment_label
      managed-by  = "terraform"
      project     = "kijanikiosk"
    }
  }
}

# Resource quota keeps staging from starving other namespaces on a local cluster.
resource "kubernetes_resource_quota" "staging_quota" {
  metadata {
    name      = "kijani-staging-quota"
    namespace = kubernetes_namespace.staging.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = "1"
      "requests.memory" = "1Gi"
      "limits.cpu"      = "2"
      "limits.memory"   = "2Gi"
      "pods"            = "10"
    }
  }
}

output "staging_namespace_name" {
  value = kubernetes_namespace.staging.metadata[0].name
}
