module "sample-dashboard" {
  source = "git::https://github.com/port-experimental/terraform-port-dashboard.git?ref=1.0.0"

  identifier  = var.identifier
  title       = var.title
  description = var.description
  locked      = var.locked
  icon        = var.icon
  widgets     = [local.sample_dashboard.widgets]
  parent      = var.parent
}

module "ocean-integrations-dashboard" {
  source = "git::https://github.com/port-experimental/terraform-port-dashboard.git?ref=1.0.0"

  identifier  = "ocean"
  title       = "ocean-integrations"
  description = var.description
  locked      = var.locked
  icon        = var.icon
  widgets     = [local.ocean_integrations.widgets]
  parent      = var.parent
}
