variable "project" {
  # Описание переменной
  description = "Project ID"
}

variable "region" {
  description = "Region"
  # Значение по умолчанию
}

variable "zone" {
  # zone location for google_compute_instance app
  description = "Zone location"
  default     = "us-central1-c"
}

variable "initial_node_count" {
  description = "Initial node count"
  default     = 2
}
