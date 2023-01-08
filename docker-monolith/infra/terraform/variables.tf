
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
