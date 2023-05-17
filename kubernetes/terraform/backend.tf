# Указываем путь где мы будем хранить наш stage file
terraform {
  backend "gcs" {
    bucket = "micro-bucket-258b7b2f0f950e70" # имя нашего bucket
    prefix = "kuberbetes"
  }
}
