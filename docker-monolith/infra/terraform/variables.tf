
variable "project" {
  # Описание переменной
  description = "Project ID"
  default     = "docker-372311"
}

variable "region" {
  description = "Region"
  # Значение по умолчанию
  default = "europe-west1"
}

variable "number_of_instances" {
  description = "Number of reddit-app instances (count)"
  default     = 1
}

variable "zone" {
  # zone location for google_compute_instance app
  description = "Zone location"
  default     = "europe-west1-b"
}

variable "disk_image" {
  description = "Disk image"
  default = "docker-host"
}

variable "label_env" {
  description = "GCP label 'env' associating an instance with an environment in which it's being run (e.g. stage, prod)"
  default     = "stage"
}

variable "private_key_path" {
  description = "Path to the private key used for ssh provisioners"
  default = "~/.ssh/id_rsa"
}
