terraform {
  # Версия terraform
  # required_version = "1.3.5"
  required_providers {
    google = {
      source  = "hashicorp/google" # Указываем провайдера терраформ
      version = "~> 4.43.1"        # можем также указать версию провайдера
    }
  }
}

# Указываем провайдера
provider "google" {
  # ID проекта
  project = var.project
  region  = var.region
}

resource "google_compute_instance" "app" {
  # Количество инстансов которое мы будем создавать
  count        = var.number_of_instances
  # автоматически добавляем к каждому новому инстансу следующий номер
  name         = "docker-host-${count.index}"
  machine_type = "g1-small"
  zone         = var.zone

  # Определяем теги для правил Firewall если определяем тег http-server то gcp автоматически открывает порт 80
  tags         = ["docker-machine"]

  labels       = {
    # определяем labels для ansible dynamic inventory
    ansible_group = "docker-host"
    env           = var.label_env
  }

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = var.disk_image # Также можно передать полное имя образа, например "reddit-base-1668709415"
    }
  }

  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network    = "default"
    # network_ip = var.internal_ip_app
    # использовать ephemeral IP для доступа из Интернет
    access_config {
      nat_ip = "${element(google_compute_address.app_ip.*.address, count.index)}"
    }
    # Использовать настроенный нами внешний статический ip:
    /* access_config {
      nat_ip = google_compute_address.app_ip.address
    } */
  }
  
    # Параметры подключения провижионеров
  /* connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    private_key = file(var.private_key)
    host = self.network_interface[0].access_config[0].nat_ip
  } */
}

resource "google_compute_address" "app_ip" {
  count  = var.number_of_instances
  name   = "docker-host-${count.index}"
  region = var.region
}
