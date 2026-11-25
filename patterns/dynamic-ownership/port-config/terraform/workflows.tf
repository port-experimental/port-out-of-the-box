locals {
  svc = var.service_blueprint_identifier

  # Roles and teams allowed to run the swarm forms.
  requestor_permissions = {
    roles = var.workflow_requestor_roles
    teams = var.workflow_requestor_teams
  }

  # Appends are done in two steps because a workflow cannot read an entity before writing it.
  # A form stages the new value on the entity. An event workflow then appends it to the
  # existing list and clears the staging field.
  log_condition = "((.diff.before.team // []) | sort) != ((.diff.after.team // []) | sort)"
}

# 1. Create a swarm: a temporary team under a long-lived parent team.
resource "port_workflow" "create_swarm" {
  identifier                = "create_swarm"
  title                     = "Create swarm"
  description               = "Creates a swarm: a temporary team under a long-lived parent team."
  allow_anyone_to_view_runs = true

  node {
    identifier = "trigger"
    title      = "Create a swarm"

    self_serve_trigger {
      published = true

      user_inputs {
        user_properties = {
          string_props = {
            swarm_name = {
              title = "Swarm name"
            }
            period = {
              title = "Period"
            }
            parent_team = {
              title     = "Parent team"
              format    = "entity"
              blueprint = "_team"
            }
            description = {
              title = "Description"
            }
          }
        }
        order_properties = ["swarm_name", "period", "parent_team", "description"]
      }

      permissions {
        roles = local.requestor_permissions.roles
        teams = local.requestor_permissions.teams
      }
    }
  }

  node {
    identifier = "upsert_entity_16460ee06e7d4641"
    title      = "Create swarm team"

    upsert_entity {
      blueprint_identifier = "_team"
      on_failure           = "terminate"

      mapping {
        identifier = "swarm-{{ .outputs.trigger.swarm_name | ascii_downcase | gsub(\"[^a-z0-9]+\"; \"-\") }}-{{ .outputs.trigger.period | ascii_downcase }}"
        title      = "{{ .outputs.trigger.swarm_name }} swarm {{ .outputs.trigger.period }}"
        properties = jsonencode({
          type      = "team"
          period    = "{{ .outputs.trigger.period }}"
          status    = "planned"
          team_kind = "swarm"
        })
        relations = jsonencode({
          parent_team = "{{ .outputs.trigger.parent_team }}"
        })
      }
    }
  }

  connections {
    source_identifier = "trigger"
    target_identifier = "upsert_entity_16460ee06e7d4641"
  }

  depends_on = [port_system_blueprint.team]
}

# 2a. Form: stage a swarm on a user.
resource "port_workflow" "add_user_to_swarm" {
  identifier                = "add_user_to_swarm"
  title                     = "Add user to swarm"
  description               = "Stages a swarm on a user. apply_pending_swarm then appends it to the user's teams."
  allow_anyone_to_view_runs = true

  node {
    identifier = "trigger"
    title      = "Add user to swarm"

    self_serve_trigger {
      published = true

      user_inputs {
        user_properties = {
          string_props = {
            user = {
              title     = "User"
              format    = "entity"
              blueprint = "_user"
              required  = true
            }
            swarm = {
              title     = "Swarm"
              format    = "entity"
              blueprint = "_team"
              required  = true
            }
          }
        }
        order_properties = ["user", "swarm"]
      }

      permissions {
        roles = local.requestor_permissions.roles
        teams = local.requestor_permissions.teams
      }
    }
  }

  node {
    identifier = "set_pending_swarm"
    title      = "Set pending swarm on user"

    upsert_entity {
      blueprint_identifier = "_user"
      on_failure           = "terminate"

      mapping {
        identifier = "{{ .outputs.trigger.user }}"
        properties = jsonencode({
          pending_swarm = "{{ .outputs.trigger.swarm }}"
        })
      }
    }
  }

  connections {
    source_identifier = "trigger"
    target_identifier = "set_pending_swarm"
  }

  depends_on = [port_system_blueprint.user, port_system_blueprint.team]
}

# 2b. Event: append the staged swarm to the user's teams and clear the staging field.
resource "port_workflow" "apply_pending_swarm" {
  identifier                = "apply_pending_swarm"
  title                     = "Apply pending swarm to user"
  description               = "Appends the staged swarm to the user's teams, keeps their other teams, and clears the staging field."
  allow_anyone_to_view_runs = true

  node {
    identifier = "trigger"
    title      = "User has a pending swarm"

    event_trigger {
      type                 = "ENTITY_UPDATED"
      blueprint_identifier = "_user"
      published            = true

      condition {
        combinator  = "and"
        expressions = [".diff.after.properties.pending_swarm != null and .diff.after.properties.pending_swarm != \"\""]
      }
    }
  }

  node {
    identifier = "add_swarm_to_teams"
    title      = "Add swarm to user's teams and clear pending"

    upsert_entity {
      blueprint_identifier = "_user"
      on_failure           = "terminate"

      mapping {
        identifier = "{{ .outputs.trigger.diff.after.identifier }}"
        teams      = ["{{ (.outputs.trigger.diff.after.team + [.outputs.trigger.diff.after.properties.pending_swarm]) | unique }}"]
        properties = jsonencode({
          pending_swarm = null
        })
      }
    }
  }

  connections {
    source_identifier = "trigger"
    target_identifier = "add_swarm_to_teams"
  }

  depends_on = [port_system_blueprint.user]
}

# 3a. Form: stage a swarm on a service.
resource "port_workflow" "add_swarm_to_service" {
  identifier                = "add_swarm_to_service"
  title                     = "Add swarm to service"
  description               = "Stages a swarm on a service. apply_pending_owner then appends it, and its parent team, to the owners."
  allow_anyone_to_view_runs = true

  node {
    identifier = "trigger"
    title      = "Add swarm to service"

    self_serve_trigger {
      published = true

      user_inputs {
        user_properties = {
          string_props = {
            service = {
              title     = "Service"
              format    = "entity"
              blueprint = local.svc
              required  = true
            }
            swarm = {
              title     = "Swarm"
              format    = "entity"
              blueprint = "_team"
              required  = true
            }
          }
        }
        order_properties = ["service", "swarm"]
      }

      permissions {
        roles = local.requestor_permissions.roles
        teams = local.requestor_permissions.teams
      }
    }
  }

  node {
    identifier = "set_pending_swarm"
    title      = "Set pending swarm on service"

    upsert_entity {
      blueprint_identifier = local.svc
      on_failure           = "terminate"

      mapping {
        identifier = "{{ .outputs.trigger.service }}"
        relations = jsonencode({
          pending_swarm = "{{ .outputs.trigger.swarm }}"
        })
      }
    }
  }

  connections {
    source_identifier = "trigger"
    target_identifier = "set_pending_swarm"
  }

  depends_on = [port_blueprint.service, port_system_blueprint.team]
}

# 3b. Event: append the staged swarm and its parent team to the service owners, then clear the relation.
resource "port_workflow" "apply_pending_owner" {
  identifier                = "apply_pending_owner"
  title                     = "Apply pending swarm to service owners"
  description               = "Appends the staged swarm and its parent team to the service owners, keeps existing owners, and clears the staging relation."
  allow_anyone_to_view_runs = true

  node {
    identifier = "trigger"
    title      = "Service has a pending swarm"

    event_trigger {
      type                 = "ENTITY_UPDATED"
      blueprint_identifier = local.svc
      published            = true

      condition {
        combinator  = "and"
        expressions = [".diff.after.relations.pending_swarm != null and .diff.after.relations.pending_swarm != \"\""]
      }
    }
  }

  node {
    identifier = "add_swarm_and_parent_to_owners"
    title      = "Add swarm and its parent to owners, clear pending"

    upsert_entity {
      blueprint_identifier = local.svc
      on_failure           = "terminate"

      mapping {
        identifier = "{{ .outputs.trigger.diff.after.identifier }}"
        teams      = ["{{ ([.outputs.trigger.diff.after.team, [.outputs.trigger.diff.after.relations.pending_swarm], [(.outputs.trigger.diff.after.properties.pending_swarm_parent // .outputs.trigger.diff.after.mirrorProperties.pending_swarm_parent)]] | flatten | map(select(. != null and . != \"\")) | unique) }}"]
        relations = jsonencode({
          pending_swarm = null
        })
      }
    }
  }

  connections {
    source_identifier = "trigger"
    target_identifier = "add_swarm_and_parent_to_owners"
  }

  depends_on = [port_blueprint.service, port_system_blueprint.team]
}

# 4a. Audit trail: record every change to a service's owning teams.
resource "port_workflow" "log_service_owner_change" {
  identifier                = "log_service_owner_change"
  title                     = "Log service owner change"
  description               = "Writes an ownership_change record whenever a service's owning teams change."
  allow_anyone_to_view_runs = true

  node {
    identifier = "trigger"
    title      = "Log service owner change"

    event_trigger {
      type                 = "ENTITY_UPDATED"
      blueprint_identifier = local.svc
      published            = true

      condition {
        combinator  = "and"
        expressions = [local.log_condition]
      }
    }
  }

  node {
    identifier = "record"
    title      = "Record ownership change"

    upsert_entity {
      blueprint_identifier = port_blueprint.ownership_change.identifier
      on_failure           = "terminate"

      mapping {
        identifier = "{{ .workflowRun.identifier }}"
        title      = "{{ .outputs.trigger.diff.after.identifier }} team change"
        properties = jsonencode({
          entity      = "{{ .outputs.trigger.diff.after.identifier }}"
          entity_type = "service"
          change_type = "owning_team"
          before      = "{{ (.outputs.trigger.diff.before.team // []) | join(\", \") }}"
          after       = "{{ (.outputs.trigger.diff.after.team // []) | join(\", \") }}"
          changed_at  = "{{ now | todateiso8601 }}"
          changed_by  = "{{ .outputs.trigger.diff.after.updatedBy }}"
          source      = "workflow"
        })
      }
    }
  }

  connections {
    source_identifier = "trigger"
    target_identifier = "record"
  }

  depends_on = [port_blueprint.service]
}

# 4b. Audit trail: record every change to a user's teams.
resource "port_workflow" "log_user_team_change" {
  identifier                = "log_user_team_change"
  title                     = "Log user team change"
  description               = "Writes an ownership_change record whenever a user's teams change."
  allow_anyone_to_view_runs = true

  node {
    identifier = "trigger"
    title      = "Log user team change"

    event_trigger {
      type                 = "ENTITY_UPDATED"
      blueprint_identifier = "_user"
      published            = true

      condition {
        combinator  = "and"
        expressions = [local.log_condition]
      }
    }
  }

  node {
    identifier = "record"
    title      = "Record ownership change"

    upsert_entity {
      blueprint_identifier = port_blueprint.ownership_change.identifier
      on_failure           = "terminate"

      mapping {
        identifier = "{{ .workflowRun.identifier }}"
        title      = "{{ .outputs.trigger.diff.after.identifier }} team change"
        properties = jsonencode({
          entity      = "{{ .outputs.trigger.diff.after.identifier }}"
          entity_type = "user"
          change_type = "membership"
          before      = "{{ (.outputs.trigger.diff.before.team // []) | join(\", \") }}"
          after       = "{{ (.outputs.trigger.diff.after.team // []) | join(\", \") }}"
          changed_at  = "{{ now | todateiso8601 }}"
          changed_by  = "{{ .outputs.trigger.diff.after.updatedBy }}"
          source      = "workflow"
        })
      }
    }
  }

  connections {
    source_identifier = "trigger"
    target_identifier = "record"
  }

  depends_on = [port_system_blueprint.user]
}
