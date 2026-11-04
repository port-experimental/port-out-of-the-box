terraform {
  //  backend "s3" {
  //    bucket       = "<terraform-state-bucket>"
  //    key          = "sdlc/root-module/terraform.tfstate"
  //    region       = "<region>"
  //    encrypt      = true
  //    use_lockfile = true
  //  }

  required_providers {
    port = {
      source  = "port-labs/port-labs"
      version = ">= 2.33.2"
    }
  }
}

# Credentials are read from the PORT_CLIENT_ID and PORT_CLIENT_SECRET environment
# variables, which are managed outside this configuration.
provider "port" {}
