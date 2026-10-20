terraform {
  required_providers {
    port = {
      source  = "port-labs/port-labs"
      version = ">= 2.32.2"
    }
  }
}

provider "port" {
  client_id = var.PORT_CLIENT_ID
  secret    = var.PORT_CLIENT_SECRET
}
