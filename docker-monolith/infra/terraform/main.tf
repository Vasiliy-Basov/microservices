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

module "app" {
  source          = "../modules/app"
  zone            = var.zone
  app_disk_image  = var.app_disk_image
  public_key      = var.public_key
  prod_or_stage   = var.prod_or_stage
  private_key     = var.private_key
  ssh_user        = var.ssh_user
  internal_ip_db  = module.intip.internal_ip_db
  internal_ip_app = module.intip.internal_ip_app
  enable_provisioners = var.enable_provisioners
}
