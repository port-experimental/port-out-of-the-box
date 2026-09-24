module "sample-integration" {
  source = "github.com/port-experimental/terraform-port-integration?ref=v1.0.0"

  title                 = "sample-integration"
  installation_id       = "sample-integration-prod"
  installation_app_type = "linear"
  installation_type     = "Saas"

  spec   = local.spec
  config = null //local.config
  //Integrations receive default mappings during provisioning. Create the integration first (without config), then add config to your HCL and run 'terraform apply' again to override the defaults.
}