terraform {
  required_version = ">= 1.5"

  required_providers {
    port = {
      source  = "port-labs/port-labs"
      version = ">= 2.36.2"
    }
  }
}

provider "port" {
  client_id = var.port_client_id
  secret    = var.port_client_secret
  # Leave null for the provider default. Set it for other regions, for example "https://api.us.getport.io".
  base_url = var.port_base_url
}
