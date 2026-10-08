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
            "Investigate the given incident using Port's context lake and any relevant Notion runbooks or postmortem docs,",
            "then produce a concise, structured triage summary.",
          ])
          user_prompt = join(" ", [
            "Triage incident \"{{ .outputs.trigger.incident }}\".",
            "Look up the incident entity (and its related service) in Port, then search Notion for any runbooks,",
            "on-call docs, or past postmortems relevant to this service or failure mode.",
            "Produce a triage summary covering: what's happening, likely severity, and recommended next steps.",
          ])
          tools = [
            "list_blueprints",
            "list_entities",
            "notion_.*",
          ]
          mcp_servers = [
            {
              identifier = "notion"
            }
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
              recommended_action = {
                type = "string"
              }
            }
            required = ["summary", "severity"]
          })
        }
      },
      {
        identifier = "notify-slack"
        title      = "Notify Slack"

        webhook = {
          url          = "https://slack.com/api/chat.postMessage"
          method       = "POST"
          synchronized = true
          agent        = false
          on_timeout   = "fail"
          on_failure   = "continue"
          headers = {
            Content-Type  = "application/json"
            Authorization = "Bearer {{ .secrets[\"SLACK_BOT_TOKEN\"] }}"
          }
          body = {
            channel = "#incidents"
            text    = <<-EOT
              *Incident triage for {{ .outputs.trigger.incident }}* (severity: {{ .outputs["ai-triage"].response | fromjson | .severity }})
              {{ .outputs["ai-triage"].response | fromjson | .summary }}
            EOT
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
        target_identifier = "notify-slack"
      },
    ]
  }
}
