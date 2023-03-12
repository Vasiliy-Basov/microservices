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

# Resource to create the GKE Cluster
resource "google_container_cluster" "dev-cluster" {
  name               = "dev-cluster"
  location           = "us-central1-c"
  initial_node_count = 1
  remove_default_node_pool = true

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

resource "google_container_node_pool" "primary_nodes" {
  name       = "my-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.dev-cluster.id
  node_count = 2

  node_config {
    machine_type = "g1-small"
    disk_size_gb = 20
    # oauth_scopes - это список OAuth-областей видимости, которые необходимо предоставить сервисному аккаунту. 
    # В данном случае, указана область видимости https://www.googleapis.com/auth/cloud-platform, которая предоставляет доступ к ресурсам Google Cloud Platform.
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]    
  }
}
