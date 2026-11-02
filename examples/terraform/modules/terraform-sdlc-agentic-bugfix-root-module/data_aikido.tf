locals {
  aikido_vuln_cursor_triage_jira = {
    nodes = [
      {
        identifier = "trigger"

        event_trigger = {
          type                 = "ENTITY_CREATED"
          blueprint_identifier = "aikidoVulnerability"
          published            = true
        }
      },
      {
        identifier = "fetch_service"
        title      = "Fetch impacted service"
        icon       = "Service"

        webhook = {
          url          = "https://api.port.io/v1/blueprints/service/entities/search"
          method       = "POST"
          agent        = false
          synchronized = true
          headers = {
            "Content-Type" = "application/json"
          }
          body = {
            query = {
              rules = [
                {
                  value    = "{{ .outputs.trigger.diff.after.relations.service | if type == \"object\" then .identifier else . end }}"
                  operator = "="
                  property = "$identifier"
                },
              ]
              combinator = "and"
            }
          }
          on_timeout = "fail"
          on_failure = "continue"
        }

        variables = {
          title          = "{{ .result.response.data.entities[0].title // \"Unknown service\" }}"
          entity         = "{{ .result.response.data.entities[0] }}"
          github_url     = "{{ .result.response.data.entities[0].properties.github_url // .result.response.data.entities[0].properties.url // \"\" }}"
          identifier     = "{{ .result.response.data.entities[0].identifier // \"\" }}"
          criticality    = "{{ .result.response.data.entities[0].properties.criticality // \"unknown\" }}"
          default_branch = "{{ .result.response.data.entities[0].properties.github_default_branch // \"develop\" }}"
        }
      },
      {
        identifier = "assess_impact"
        title      = "Assess service impact"
        icon       = "AI"

        ai = {
          system_prompt = "You are a security triage analyst. Be factual and concise. Prefer catalog evidence."
          user_prompt   = <<-EOT
            A new Aikido vulnerability was ingested into Port.

            Vulnerability:
            - Identifier: {{ .outputs.trigger.diff.after.identifier }}
            - Title: {{ .outputs.trigger.diff.after.title }}
            - Severity: {{ .outputs.trigger.diff.after.properties.severity }}
            - CVE: {{ .outputs.trigger.diff.after.properties.cve_id }}
            - CVSS: {{ .outputs.trigger.diff.after.properties.cvss_score }}
            - Package: {{ .outputs.trigger.diff.after.properties.affected_package }} {{ .outputs.trigger.diff.after.properties.affected_version }}
            - Fixed version: {{ .outputs.trigger.diff.after.properties.fixed_version }}
            - Description: {{ .outputs.trigger.diff.after.properties.description }}
            - URL: {{ .outputs.trigger.diff.after.properties.url }}

            Related service:
            - Identifier: {{ .outputs.fetch_service.identifier }}
            - Title: {{ .outputs.fetch_service.title }}
            - Criticality: {{ .outputs.fetch_service.criticality }}
            - GitHub URL: {{ .outputs.fetch_service.github_url }}

            Return structured JSON: impact_summary, severity (Critical|High|Medium|Low), affected_components, recommended_actions.
          EOT
          tools = [
            "list_blueprints",
            "list_entities",
          ]
          output_schema = jsonencode({
            type = "object"
            properties = {
              severity = {
                type = "string"
              }
              impact_summary = {
                type = "string"
              }
              affected_components = {
                type = "string"
              }
              recommended_actions = {
                type = "string"
              }
            }
            required = ["impact_summary", "severity", "affected_components", "recommended_actions"]
          })
        }

        variables = {
          response            = "{{ .result.response }}"
          severity            = "{{ (.result.response | if type == \"string\" then fromjson else . end).severity }}"
          impact_summary      = "{{ (.result.response | if type == \"string\" then fromjson else . end).impact_summary }}"
          affected_components = "{{ (.result.response | if type == \"string\" then fromjson else . end).affected_components }}"
          recommended_actions = "{{ (.result.response | if type == \"string\" then fromjson else . end).recommended_actions }}"
        }
      },
      {
        identifier = "has_repo"
        title      = "Service has GitHub repo?"
        icon       = "Git"

        condition = {
          outlets = [
            {
              identifier = "with_repo"
              title      = "Has repository"
              expression = "(.outputs.fetch_service.github_url // \"\") != \"\""
            },
            {
              identifier = "without_repo"
              title      = "No repository"
              expression = "(.outputs.fetch_service.github_url // \"\") == \"\""
            },
          ]
        }
      },
      {
        identifier = "cursor_triage"
        title      = "Cursor remediates via PR"
        icon       = "Cursor"

        integration_action = {
          installation_id             = "cursor-cloud-agents"
          integration_provider        = "cursor-cloud-agents"
          integration_invocation_type = "create_agent"
          execution_properties = {
            ref              = "{{ .outputs.fetch_service.default_branch // \"develop\" }}"
            prompt           = <<-EOT
              Remediate this security vulnerability with a minimal PR.

              Title: {{ .outputs.trigger.diff.after.title }}
              Severity: {{ .outputs.trigger.diff.after.properties.severity }}
              CVE: {{ .outputs.trigger.diff.after.properties.cve_id }}
              Package: {{ .outputs.trigger.diff.after.properties.affected_package }}
              Affected: {{ .outputs.trigger.diff.after.properties.affected_version }}
              Fixed: {{ .outputs.trigger.diff.after.properties.fixed_version }}
              Description: {{ .outputs.trigger.diff.after.properties.description }}

              Service: {{ .outputs.fetch_service.title }}
              Impact: {{ .outputs.assess_impact.impact_summary }}
              Base branch (MUST use this, not main unless it is literally main): {{ .outputs.fetch_service.default_branch // "develop" }}

              Locate the pinned package/runtime version and bump it to the fixed version. Prefer Remi module form in Packer HCL when applicable (php:remi-X.Y). Open a PR into {{ .outputs.fetch_service.default_branch // "develop" }}. If an open PR already has this fix targeting that base, link it instead of duplicating. Summarize files changed and PR URL.
            EOT
            apiVersion       = "v0"
            repository       = "{{ .outputs.fetch_service.github_url }}"
            autoCreatePr     = true
            reportCompletion = true
          }
          on_failure = "continue"
        }

        variables = {
          prUrl    = "{{ .result.response.target.prUrl // .result.target.prUrl // \"\" }}"
          status   = "{{ .result.response.status // .result.status // \"\" }}"
          agentId  = "{{ .result.response.agentId // .result.agentId // \"\" }}"
          summary  = "{{ .result.response.summary // .result.summary // \"Cursor remediation completed.\" }}"
          agentUrl = "{{ .result.response.target.url // .result.target.url // \"\" }}"
        }
      },
      {
        identifier = "create_jira_with_cursor"
        title      = "Create Jira ticket (SD)"
        icon       = "Jira"

        webhook = {
          url          = "https://api.atlassian.com/ex/jira/${var.jira_cloud_id}/rest/api/2/issue"
          method       = "POST"
          agent        = false
          synchronized = true
          headers = {
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer {{ .secrets.__JIRA_JIRA_ATLASSIAN_USER_TOKEN }}"
          }
          body = {
            fields = {
              project = {
                key = "SD"
              }
              summary = "[Aikido {{ .outputs.trigger.diff.after.properties.severity }}] {{ .outputs.trigger.diff.after.title }} — {{ .outputs.fetch_service.title }}"
              issuetype = {
                name = "Task"
              }
              description = <<-EOT
                Aikido: {{ .outputs.trigger.diff.after.identifier }}
                Severity: {{ .outputs.trigger.diff.after.properties.severity }} (assessed {{ .outputs.assess_impact.severity }})
                CVE: {{ .outputs.trigger.diff.after.properties.cve_id }}
                Package: {{ .outputs.trigger.diff.after.properties.affected_package }} {{ .outputs.trigger.diff.after.properties.affected_version }} -> {{ .outputs.trigger.diff.after.properties.fixed_version }}
                Service: {{ .outputs.fetch_service.title }}

                {{ .outputs.assess_impact.impact_summary }}

                Actions:
                {{ .outputs.assess_impact.recommended_actions }}

                Cursor: {{ .outputs.cursor_triage.agentUrl }}
                PR: {{ .outputs.cursor_triage.prUrl }}

                {{ .outputs.cursor_triage.summary }}
              EOT
            }
          }
          on_timeout = "fail"
          on_failure = "terminate"
        }

        variables = {
          issueId   = "{{ .result.response.data.id }}"
          issueKey  = "{{ .result.response.data.key }}"
          response  = "{{ .result.response }}"
          issueSelf = "{{ .result.response.data.self }}"
        }
      },
      {
        identifier = "create_jira_without_cursor"
        title      = "Create Jira ticket (SD, no repo)"
        icon       = "Jira"

        webhook = {
          url          = "https://api.atlassian.com/ex/jira/${var.jira_cloud_id}/rest/api/2/issue"
          method       = "POST"
          agent        = false
          synchronized = true
          headers = {
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer {{ .secrets.__JIRA_JIRA_ATLASSIAN_USER_TOKEN }}"
          }
          body = {
            fields = {
              project = {
                key = "SD"
              }
              summary = "[Aikido {{ .outputs.trigger.diff.after.properties.severity }}] {{ .outputs.trigger.diff.after.title }} — {{ .outputs.fetch_service.title }}"
              issuetype = {
                name = "Task"
              }
              description = <<-EOT
                Aikido: {{ .outputs.trigger.diff.after.identifier }}
                Severity: {{ .outputs.trigger.diff.after.properties.severity }} (assessed {{ .outputs.assess_impact.severity }})
                CVE: {{ .outputs.trigger.diff.after.properties.cve_id }}
                Package: {{ .outputs.trigger.diff.after.properties.affected_package }} {{ .outputs.trigger.diff.after.properties.affected_version }} -> {{ .outputs.trigger.diff.after.properties.fixed_version }}
                Service: {{ .outputs.fetch_service.title }}

                {{ .outputs.assess_impact.impact_summary }}

                Actions:
                {{ .outputs.assess_impact.recommended_actions }}

                Cursor skipped: no github_url.
              EOT
            }
          }
          on_timeout = "fail"
          on_failure = "terminate"
        }

        variables = {
          issueId   = "{{ .result.response.data.id }}"
          issueKey  = "{{ .result.response.data.key }}"
          response  = "{{ .result.response }}"
          issueSelf = "{{ .result.response.data.self }}"
        }
      },
    ]

    connections = [
      {
        source_identifier = "trigger"
        target_identifier = "fetch_service"
      },
      {
        source_identifier = "fetch_service"
        target_identifier = "assess_impact"
      },
      {
        source_identifier = "assess_impact"
        target_identifier = "has_repo"
      },
      {
        source_identifier        = "has_repo"
        target_identifier        = "cursor_triage"
        source_outlet_identifier = "with_repo"
      },
      {
        source_identifier        = "has_repo"
        target_identifier        = "create_jira_without_cursor"
        source_outlet_identifier = "without_repo"
      },
      {
        source_identifier = "cursor_triage"
        target_identifier = "create_jira_with_cursor"
      },
    ]
  }
}
