# Можем хранить terraform.tfstate файл в том же бакете который мы создаем этим терраформом
terraform {
  backend "gcs" {
    bucket = "kub-bucket-bd3cf29fda5e855a" # имя нашего bucket
    prefix = "bucket"
  }
}
