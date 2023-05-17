terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
 #     version = "~> 4.44.1"
    }
  }
}

provider "google" {
  # ID проекта
  project = var.project
  region  = var.region
}

# Это плагин который генерирует random id:
resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "default" {
  name          = "micro-bucket-${random_id.bucket_prefix.hex}"
  force_destroy = false      # не даст удалить bucket пока не удалим все внутренние объекты
  location      = "EU"       # https://cloud.google.com/storage/docs/locations
  storage_class = "STANDARD" # Supported values include: STANDARD, MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, ARCHIVE
  project       = var.project
  versioning { # При изменении объекта старые версии сохраняются
    enabled = true
  }
  # Предотвращаем удаление бакета
  lifecycle {
    prevent_destroy = true
  }
}

# Устанавливаем права для доступа к бакету через acl
resource "google_storage_bucket_acl" "state_storage_bucket_acl" {
  bucket = google_storage_bucket.default.name
  predefined_acl = "private"
}
