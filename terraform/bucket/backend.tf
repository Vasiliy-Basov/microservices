# Можем хранить terraform.tfstate файл в том же бакете который мы создаем этим терраформом
terraform {
  backend "gcs" {
    bucket = "micro-bucket-258b7b2f0f950e70" # имя нашего bucket
    prefix = "bucket"
  }
}
