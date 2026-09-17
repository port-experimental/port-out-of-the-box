module "environment_blueprint" {
  source = "git::https://github.com/port-experimental/terraform-port-blueprint.git?ref=1.0.0"

  identifier                    = "Sample_Environment_Blueprint"
  title                         = "Sample Environment Blueprint"
  icon                          = "Environment"
  description                   = "Sample Environment blueprint deployed via Terraform"
  create_catalog_page           = var.create_catalog_page
  include_in_global_search      = var.include_in_global_search
  force_delete_entities         = var.force_delete_entities
  ownership                     = var.ownership
  webhook_changelog_destination = var.webhook_changelog_destination
  kafka_changelog_destination   = var.kafka_changelog_destination
  properties                    = local.environment_blueprint.properties
  mirror_properties             = local.environment_blueprint.mirror_properties
  calculation_properties        = local.environment_blueprint.calculation_properties
}

module "microservice_blueprint" {
  source = "git::https://github.com/port-experimental/terraform-port-blueprint.git?ref=1.0.0"

  identifier                    = "Sample_Microservice_Blueprint"
  title                         = "Sample Microservice Blueprint"
  icon                          = "Microservice"
  description                   = "Sample Microservice blueprint deployed via Terraform"
  create_catalog_page           = var.create_catalog_page
  include_in_global_search      = var.include_in_global_search
  force_delete_entities         = var.force_delete_entities
  ownership                     = var.ownership
  webhook_changelog_destination = var.webhook_changelog_destination
  kafka_changelog_destination   = var.kafka_changelog_destination
  properties                    = local.microservice_blueprint.properties
  relations               = local.microservice_blueprint.relations
  mirror_properties             = local.microservice_blueprint.mirror_properties
  calculation_properties        = local.microservice_blueprint.calculation_properties
}

module "environment_entity" {
  source = "git::https://github.com/port-experimental/terraform-port-entity.git?ref=1.0.1"

  blueprint  = module.environment_blueprint.id
  title      = "Sample Environment Entity"
  identifier = "sample_environment_entity"
  properties = local.environment_entity.properties
}

module "miroservice_entity" {
  source = "git::https://github.com/port-experimental/terraform-port-entity.git?ref=1.0.1"

  blueprint  = module.microservice_blueprint.id
  title      = "Sample Microservice Entity"
  identifier = "sample_microservice_entity"
  properties = local.microservice_entity.properties
  relations  = local.microservice_entity.relations
}