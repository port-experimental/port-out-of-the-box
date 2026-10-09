locals {
  incident_auto_triage = {
    nodes = [
      {
        identifier = "trigger"

        self_serve_trigger = {
          published = true
          permissions = {
            roles = ["Member"]
          }
          user_inputs = {
            user_properties = {
              string_props = {
                incident = {
                  title       = "Incident"
                  description = "The incident to triage."
                  format      = "entity"
                  blueprint   = "incident"
                  required    = true
                }
              }
            }
            order_properties = ["incident"]
          }
        }
      },
      {
        identifier = "ai-triage"
        title      = "AI triage"

        ai = {
          provider = "port"
          model    = "claude-sonnet-5"
          system_prompt = join(" ", [
            "You are an incident triage analyst.",
            "Investigate the given incident using Port's context lake,",
            "then produce a concise, structured triage summary.",
          ])
          user_prompt = join(" ", [
            "Triage incident \"{{ .outputs.trigger.incident }}\".",
            "Look up the incident entity and its related service in Port.",
            "Produce a triage summary covering what is happening, likely severity, root cause, and recommended next steps.",
            "Set severity to one of critical, high, medium, or low.",
          ])
          tools = [
            "list_blueprints",
            "list_entities",
          ]
          output_schema = jsonencode({
            type = "object"
            properties = {
              summary = {
                type = "string"
              }
              severity = {
                type = "string"
              }
              root_cause = {
                type = "string"
              }
              recommended_action = {
                type = "string"
              }
            }
            required = ["summary", "severity", "root_cause", "recommended_action"]
          })
        }
      },
      {
        identifier = "update-incident"
        title      = "Update Incident"

        upsert_entity = {
          blueprint_identifier = "incident"
          on_failure           = "terminate"
          mapping = {
            identifier = "{{ .outputs.trigger.incident }}"
            properties = {
              status     = "investigating"
              severity   = "{{ .outputs[\"ai-triage\"].response | fromjson | .severity }}"
              root_cause = "{{ .outputs[\"ai-triage\"].response | fromjson | .root_cause }}"
              analysis   = <<-EOT
                {{ .outputs["ai-triage"].response | fromjson | .summary }}

                ## Recommended action

                {{ .outputs["ai-triage"].response | fromjson | .recommended_action }}
              EOT
            }
          }
        }
      },
    ]

    connections = [
      {
        source_identifier = "trigger"
        target_identifier = "ai-triage"
      },
      {
        source_identifier = "ai-triage"
        target_identifier = "update-incident"
      },
    ]
  }
}
