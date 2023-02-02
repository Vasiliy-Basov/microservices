terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.43.1" 
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

/* resource "google_service_account" "docker" {
  account_id = "docker"
}  */


# Создаем внешний ip адрес
resource "google_compute_address" "app_ip" {
  name = "app-ip"
}

# Добавляем публичный ssh-key для подключения provisioner по ssh
resource "google_compute_project_metadata" "ssh_keys" {
  metadata = {
    ssh-keys = "appuser:${chomp(file(var.public_key))}"
  }
}

# Добавляем VM
resource "google_compute_instance" "app" {
  name         = "app"
  machine_type = "n1-standard-1"
  zone         = var.zone
  tags         = ["app"] # можем определить теги если определяем тег http-server то gcp автоматически открывает порт 80

  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }

  # В продакшене рекомендуется удалять default нетрворк и создавать новую сеть с нужными firewall правилами 
  network_interface {
    network    = "default"
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }

  /* service_account {
    email = google_service_account.docker.email
    scopes = ["cloud-platform"]
  } */

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(var.private_key)
      host        = self.network_interface[0].access_config[0].nat_ip
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.network_interface[0].access_config[0].nat_ip}, --private-key ${var.private_key} docker.yaml"
  }
}
