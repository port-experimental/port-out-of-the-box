terraform {
  //  backend "s3" {
  //    bucket       = "<terraform-state-bucket>"
  //    key          = "port/blueprints/<DASHBOARD_IDENTIFIER>/terraform.tfstate"
  //    region       = "<region>"
  //    encrypt      = true
  //    use_lockfile = true
  //  }


  required_providers {
    port = {
      source  = "port-labs/port-labs"
      version = ">= 2.25.2"
    }
  }
}

provider "port" {
  client_id = var.PORT_CLIENT_ID
  secret    = var.PORT_CLIENT_SECRET
}
