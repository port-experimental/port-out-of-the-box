module "production_readiness_scorecard" {
  source = "git::https://github.com/port-experimental/terraform-port-scorecard.git?ref=v1.0.0"

  identifier     = var.identifier
  title          = var.title
  port_blueprint = var.port_blueprint
  rules          = local.production_readiness.rules
}
