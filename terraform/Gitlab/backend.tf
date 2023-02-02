# Указываем путь где мы будем хранить наш stage file
terraform {
  backend "gcs" {
    bucket = "prod-bucket-f1b000bd21bd4bbf" # имя нашего bucket
    prefix = "gitlab"
  }
}
