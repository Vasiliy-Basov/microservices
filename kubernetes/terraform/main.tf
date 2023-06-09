terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
  }
}
# Provider Configuration for GCP
provider "google" {
  project = var.project
  region  = var.region
}

# Создаем ip address для ingress контроллера
resource "google_compute_address" "ingress_cluster_ip" {
  name   = "ingress-cluster-ip"
  region = var.region
  project = var.project
}

# Resource to create the GKE Cluster
resource "google_container_cluster" "dev-cluster" {
  name               = "dev-cluster"
  location           = var.zone
  initial_node_count = 1
  remove_default_node_pool = true
  # включаем устаревшие права доступа legacy Attribute-Based Access Control (для более простой настройка) по-умолчанию используется RBAC он отключится
  # enable_legacy_abac = true

  # Эта настройка отключает автоматическое создание клиентских сертификатов при настройке кластера Kubernetes. 
  # Клиентские сертификаты - это цифровые сертификаты, которые выдаются клиентам для аутентификации в кластере Kubernetes.
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
  # Включаем аддон http_load_balancing который в дальнейшем можно будет использовать для балансировки нагрузки между подами в кластере
  addons_config {
    http_load_balancing {
      disabled = false
    }
  # Аддон horizontal_pod_autoscaling в Kubernetes позволяет автоматически масштабировать количество реплик подов в зависимости от загрузки кластера. 
  # Он базируется на метриках, таких как загрузка CPU и количество соединений сети, и может настроить автоматическое масштабирование как по вертикали 
  # (изменение количества реплик пода), так и по горизонтали (изменение количества узлов в кластере).  
    horizontal_pod_autoscaling {
      disabled = false
    }
  }
    /* provisioner "local-exec" {
    command = "gcloud container clusters get-credentials dev-cluster --zone us-central1-c --project docker-377610 && kubectl apply -f ../reddit/dev-namespace.yml && kubectl apply -f ../reddit/ -n dev"
  } */
}

# Создвем ноды кластера
resource "google_container_node_pool" "primary_nodes" {
  name       = "my-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.dev-cluster.id
  node_count = var.node_count

  node_config {
    machine_type = "n2-standard-2"
    disk_size_gb = 40
    # oauth_scopes - это список OAuth-областей видимости, которые необходимо предоставить сервисному аккаунту. 
    # В данном случае, указана область видимости https://www.googleapis.com/auth/cloud-platform, которая предоставляет доступ к ресурсам Google Cloud Platform.
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]    
  }
}

# Добавляем в Cloud DNS зону basov-world запись для нашего Gitlab сервера.
resource "google_dns_record_set" "gitlab_basov_world" {
  name        = "*.cluster.basov.world."
  type        = "A"
  ttl         = 300
  managed_zone = "basov-world"
  rrdatas     = [google_compute_address.ingress_cluster_ip.address]
}

resource "null_resource" "get-credentials" {

  depends_on = [google_container_cluster.dev-cluster]  
  provisioner "local-exec" {
    command = <<-EOT
              gcloud container clusters get-credentials ${google_container_cluster.dev-cluster.name} --zone ${var.zone} --project ${var.project}
              helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
              helm repo add grafana https://grafana.github.io/helm-charts
              helm repo update
              helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --set controller.service.loadBalancerIP=${google_compute_address.ingress_cluster_ip.address} --set tcp.22="gitlab/gitlab-gitlab-shell:22"
              helm upgrade --install --wait reddit-test ../gitlab_ci/reddit/reddit
              helm upgrade --install --wait production --namespace production --create-namespace ../gitlab_ci/reddit/reddit
              helm upgrade --install --wait staging --namespace staging --create-namespace ../gitlab_ci/reddit/reddit
              helm upgrade --install --wait -f ../charts/prometheus/custom_values.yaml prometheus prometheus-community/prometheus --create-namespace --namespace prometheus
              helm upgrade --install --wait grafana grafana/grafana --set ingress.enabled=true --set ingress.ingressClassName=nginx --set ingress.hosts={grafana.cluster.basov.world} --values ../charts/grafana/grafana.yaml --create-namespace --namespace grafana
              # helm upgrade --install gitlab gitlab/gitlab --timeout 600s --set global.hosts.domain=cluster.basov.world --set global.hosts.externalIP=${google_compute_address.ingress_cluster_ip.address} --set certmanager-issuer.email=baggurd@mail.ru --set global.edition=ce --set gitlab-runner.runners.privileged=true --set global.kas.enabled=true --set global.ingress.class=nginx --set nginx-ingress.enabled=false --create-namespace --namespace gitlab
    EOT 
  }
}

# Почему то этот код не работает
/* resource "kubernetes_namespace" "gitlab_namespace" {
  depends_on = [null_resource.get-credentials]
  metadata {
    name = "gitlab"
  }
} */
