terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      # version = "~> 2.5.0"
    }
  }
}

resource "local_file" "rebrain" {
  filename = "${path.module}/hello_colleagues.txt"
  content  = "Привет! Этот файл создал Terraform с помощью провайдера 'local'."
}
