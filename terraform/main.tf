terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

resource "local_file" "example" {
  filename = "${path.module}/hello_colleagues.txt"
  content  = "Привет! Этот файл создал Terraform с помощью провайдера 'local'."
}
