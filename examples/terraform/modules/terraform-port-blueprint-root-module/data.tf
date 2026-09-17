locals {
  environment_blueprint = {
    create_catalog_page      = null
    include_in_global_search = null
    force_delete_entities    = false
    properties = {
      string_props = {
        "aws-region" = {
          title = "AWS Region"
        }
        "docs-url" = {
          title  = "Docs URL"
          format = "url"
        }
      }
    }
    mirror_properties      = {}
    calculation_properties = {}
  }

  microservice_blueprint = {
    create_catalog_page      = null
    include_in_global_search = null
    force_delete_entities    = false
    properties = {
      string_props = {
        "domain" = {
          title = "Domain"
        }
        "slack-channel" = {
          title  = "Slack Channel"
          format = "url"
        }
      }
    }
    relations = {
      "environment" = {
        target   = module.environment_blueprint.identifier
        required = true
        many     = false
      }
    }
    mirror_properties      = {}
    calculation_properties = {}
  }


  environment_entity = {
    properties = {
      string_props = {
        "aws-region" = "eu-west-1"
        "docs-url"   = "https://docs.example.com/environments/sample"
      }
    }
  }

  microservice_entity = {
    properties = {
      string_props = {
        "domain"        = "payments"
        "slack-channel" = "https://your-workspace.slack.com/archives/C0123456789"
      }
    }
relations = {
  single_relations = {
    environment = module.environment_entity.identifier
  }
}
  }
}