# Указываем путь где мы будем хранить наш stage file
terraform {
  backend "gcs" {
    bucket = "kub-bucket-bd3cf29fda5e855a" # имя нашего bucket
    prefix = "gitlab"
  }
}
