variable "project" {
  # Описание переменной
  description = "Project ID"
  default = "micro-386716"
}

variable "region" {
  description = "Region"
  default = "us-central1"
  # Значение по умолчанию
}

variable "zone" {
  # zone location for google_compute_instance app
  description = "Zone location"
  default     = "us-central1-c"
}

variable "node_count" {
  description = "Initial node count"
  default     = 2
}
