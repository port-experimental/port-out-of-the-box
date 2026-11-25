# Extends Port's built-in Team and User blueprints. Only the properties below are managed.
# The built-in properties of both blueprints are left alone.

resource "port_system_blueprint" "team" {
  identifier = "_team"

  properties = {
    string_props = {
      team_kind = {
        title       = "Team kind"
        description = "swarm is a temporary team. long_lived is a persistent team such as a domain team."
        icon        = "Team"
        enum        = ["swarm", "long_lived"]
        default     = "long_lived"
        enum_colors = {
          swarm      = "purple"
          long_lived = "green"
        }
      }
      status = {
        title   = "Status"
        icon    = "StatusPage"
        enum    = ["planned", "active", "retired"]
        default = "active"
        enum_colors = {
          planned = "yellow"
          active  = "green"
          retired = "red"
        }
      }
      period = {
        title       = "Period"
        description = "For example 2026Q4. Used for quarter-scoped swarms."
        icon        = "HourGlassExpired"
      }
      start_date = {
        title = "Start date"
        icon  = "Calendar"
      }
      end_date = {
        title = "End date"
        icon  = "Calendar"
      }
    }
  }

  relations = {
    parent_team = {
      title    = "Parent Team"
      target   = "_team"
      required = false
      many     = false
    }
  }

  mirror_properties = {
    parent_team_name = {
      title = "Parent Team"
      path  = "parent_team.$title"
    }
  }
}

resource "port_aggregation_properties" "team_size" {
  blueprint_identifier = "_team"

  properties = {
    size = {
      title                       = "Size"
      target_blueprint_identifier = "_user"
      method = {
        count_entities = true
      }
      path_filter = [{
        from_blueprint = "_user"
        path           = ["$team"]
      }]
    }
  }

  depends_on = [port_system_blueprint.team]
}

resource "port_system_blueprint" "user" {
  identifier = "_user"

  properties = {
    string_props = {
      github_login = {
        title       = "GitHub login"
        description = "GitHub username. ownership-sync uses it to manage GitHub team membership."
      }
      pending_swarm = {
        title       = "Pending swarm"
        description = "Staging field. add_user_to_swarm sets it and apply_pending_swarm clears it. Should normally be empty."
      }
    }
  }
}

# Optional. Only for new or sandbox organizations. If you already have a service blueprint,
# add the same relation, mirror property and ownership to it instead (see the README).
resource "port_blueprint" "service" {
  count = var.create_service_blueprint ? 1 : 0

  identifier = var.service_blueprint_identifier
  title      = "Service"

  ownership = {
    type = "Direct"
  }

  properties = {
    string_props = {
      name = {
        title = "Name"
      }
      description = {
        title = "Description"
      }
    }
  }

  relations = {
    pending_swarm = {
      title       = "Pending swarm"
      description = "Staging relation. add_swarm_to_service sets it and apply_pending_owner clears it. Should normally be empty."
      target      = "_team"
      required    = false
      many        = false
    }
  }

  mirror_properties = {
    pending_swarm_parent = {
      title = "Pending swarm parent"
      path  = "pending_swarm.parent_team.$identifier"
    }
  }

  depends_on = [port_system_blueprint.team]
}

resource "port_blueprint" "ownership_change" {
  identifier  = "ownership_change"
  title       = "Ownership Change"
  description = "One row per change to who owns a service or who is in a team."

  properties = {
    string_props = {
      entity = {
        title       = "Entity"
        description = "Identifier of the service, team or user that changed, for example payments_api"
      }
      entity_type = {
        title       = "Entity type"
        description = "Which kind of entity changed"
        enum        = ["service", "team", "user"]
      }
      change_type = {
        title       = "Change type"
        description = "What kind of change was made"
        enum        = ["owning_team", "membership", "parent_team"]
      }
      before = {
        title       = "Before"
        description = "Value before the change"
      }
      after = {
        title       = "After"
        description = "Value after the change"
      }
      changed_by = {
        title       = "Changed by"
        description = "Who made the change"
      }
      changed_at = {
        title       = "Changed at"
        description = "When it happened"
        format      = "date-time"
        date_format = "relative"
      }
      source = {
        title       = "Source"
        description = "How the change was made"
        enum        = ["ui", "action", "workflow"]
      }
      approved_by = {
        title       = "Approved by"
        description = "Who approved the change, when an approval step is used"
      }
      reason = {
        title       = "Reason"
        description = "Why the change was made"
      }
    }
    boolean_props = {
      self_approved = {
        title       = "Self approved"
        description = "True when the requester approved their own change"
        default     = false
      }
    }
  }
}
