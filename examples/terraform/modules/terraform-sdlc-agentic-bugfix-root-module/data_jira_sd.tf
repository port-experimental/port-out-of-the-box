locals {
  jira_sd_teams_cursor_autofix = {
    nodes = [
      {
        identifier = "trigger"
        title      = "Jira issue created (SD)"
        icon       = "Jira"

        event_trigger = {
          type                 = "ENTITY_CREATED"
          blueprint_identifier = "jiraIssue"
          published            = true
          condition = {
            expressions = [
              "(.diff.after.relations.project | if type == \"object\" then .identifier else . end) == \"SD\"",
            ]
            combinator = "and"
          }
        }
      },
      {
        identifier  = "move_in_progress"
        title       = "Move issue to In Progress"
        icon        = "Jira"
        description = "Transition the newly created SD issue into In Progress at the start of autofix."

        integration_action = {
          installation_id             = "jira"
          integration_provider        = "jira"
          integration_invocation_type = "change_issue_status"
          execution_properties = {
            status   = "In Progress"
            issueKey = "{{ .outputs.trigger.diff.after.identifier }}"
          }
          on_failure = "continue"
        }

        variables = {
          status   = "{{ .result.response.status // .result.status // \"In Progress\" }}"
          issueKey = "{{ .result.response.issueKey // .result.issueKey // .outputs.trigger.diff.after.identifier }}"
        }
      },
      {
        identifier  = "notify_teams_created"
        title       = "Notify Teams — new SD ticket"
        icon        = "Team"
        description = "Post a channel notification when an SD issue is created. Requires Port secret TEAMS_WEBHOOK_URL (Teams incoming webhook)."

        webhook = {
          url          = "{{ .secrets[\"TEAMS_WEBHOOK_URL\"] }}"
          method       = "POST"
          agent        = false
          synchronized = true
          headers = {
            "Content-Type" = "application/json"
          }
          body = {
            text       = "**{{ .outputs.trigger.diff.after.identifier }}** — {{ .outputs.trigger.diff.after.title }}\n\nStatus: In Progress (autofix started)\nType: {{ .outputs.trigger.diff.after.properties.issueType }} | Priority: {{ .outputs.trigger.diff.after.properties.priority }}\n\n{{ .outputs.trigger.diff.after.properties.description }}\n\nPort/Jira: {{ .outputs.trigger.diff.after.properties.url }}\n\nCursor triage + autofix starting (branch `bugfix/{{ .outputs.trigger.diff.after.identifier }}`)."
            "@type"    = "MessageCard"
            title      = "New Jira ticket on SD"
            summary    = "New Jira SD ticket {{ .outputs.trigger.diff.after.identifier }}"
            "@context" = "http://schema.org/extensions"
            themeColor = "0078D4"
          }
          on_timeout = "continue"
          on_failure = "continue"
        }
      },
      {
        identifier  = "resolve_repo"
        title       = "Resolve GitHub repository"
        icon        = "AI"
        description = "Map the Jira issue to a service with a GitHub URL using the linked service relation or catalog search."

        ai = {
          system_prompt = "You resolve Jira tickets to the correct Port service and GitHub repository. Prefer the linked service relation when present. Use list_entities on blueprints service and githubRepository. Always copy github_default_branch into default_branch when available. If github_default_branch is missing, prefer develop over main for this org's demo repos. Return only JSON matching the output schema. If no confident match exists, set github_url to an empty string."
          user_prompt   = <<-EOT
            A new Jira issue was created on project SD.

            Issue:
            - Key: {{ .outputs.trigger.diff.after.identifier }}
            - Title: {{ .outputs.trigger.diff.after.title }}
            - Summary: {{ .outputs.trigger.diff.after.properties.summary // .outputs.trigger.diff.after.title }}
            - Description: {{ .outputs.trigger.diff.after.properties.description }}
            - Type: {{ .outputs.trigger.diff.after.properties.issueType }}
            - Priority: {{ .outputs.trigger.diff.after.properties.priority }}
            - Linked service relation identifier (may be empty): {{ .outputs.trigger.diff.after.relations.service | if type == "object" then .identifier else . end }}

            Tasks:
            1. If a linked service exists, fetch it and read github_url / github_default_branch.
            2. Otherwise search services/repos whose name or description best matches the issue.
            3. Return the best match for Cursor agents to work in.
            4. Set default_branch to the service github_default_branch (or the GitHub repo default). Never invent "main" when github_default_branch is present.

            Return JSON fields: service_identifier, service_title, github_url, default_branch, match_reason.
          EOT
          tools = [
            "list_blueprints",
            "list_entities",
          ]
          output_schema = jsonencode({
            type = "object"
            properties = {
              github_url = {
                type = "string"
              }
              match_reason = {
                type = "string"
              }
              service_title = {
                type = "string"
              }
              default_branch = {
                type = "string"
              }
              service_identifier = {
                type = "string"
              }
            }
            required = ["service_identifier", "service_title", "github_url", "default_branch", "match_reason"]
          })
        }

        variables = {
          response           = "{{ .result.response }}"
          github_url         = "{{ (.result.response | if type == \"string\" then fromjson else . end).github_url // \"\" }}"
          match_reason       = "{{ (.result.response | if type == \"string\" then fromjson else . end).match_reason // \"\" }}"
          service_title      = "{{ (.result.response | if type == \"string\" then fromjson else . end).service_title // \"\" }}"
          default_branch     = "{{ (.result.response | if type == \"string\" then fromjson else . end).default_branch // \"develop\" }}"
          service_identifier = "{{ (.result.response | if type == \"string\" then fromjson else . end).service_identifier // \"\" }}"
        }
      },
      {
        identifier = "has_repo"
        title      = "Resolved GitHub repo?"
        icon       = "Git"

        condition = {
          outlets = [
            {
              identifier = "with_repo"
              title      = "Has repository"
              expression = "(.outputs.resolve_repo.github_url // \"\") != \"\""
            },
            {
              identifier = "without_repo"
              title      = "No repository"
              expression = "(.outputs.resolve_repo.github_url // \"\") == \"\""
            },
          ]
        }
      },
      {
        identifier  = "cursor_triage"
        title       = "Cursor triage agent"
        icon        = "Cursor"
        description = "Cloud agent analyzes the Jira issue against the repository. No PR."

        integration_action = {
          installation_id             = "cursor-cloud-agents"
          integration_provider        = "cursor-cloud-agents"
          integration_invocation_type = "create_agent"
          execution_properties = {
            ref              = "{{ .outputs.resolve_repo.default_branch // \"develop\" }}"
            prompt           = <<-EOT
              TRIAGE ONLY — do not modify files, do not commit, and do not open a pull request.

              Jira issue {{ .outputs.trigger.diff.after.identifier }}: {{ .outputs.trigger.diff.after.title }}
              Type: {{ .outputs.trigger.diff.after.properties.issueType }}
              Priority: {{ .outputs.trigger.diff.after.properties.priority }}
              URL: {{ .outputs.trigger.diff.after.properties.url }}

              Description:
              {{ .outputs.trigger.diff.after.properties.description }}

              Matched service: {{ .outputs.resolve_repo.service_title }} ({{ .outputs.resolve_repo.service_identifier }})
              Repo: {{ .outputs.resolve_repo.github_url }}
              Base ref (must use this, usually develop): {{ .outputs.resolve_repo.default_branch }}
              Match reason: {{ .outputs.resolve_repo.match_reason }}

              Inspect the repository and produce a concise triage report covering:
              1. Likely root cause
              2. Affected files/components
              3. Severity / blast radius
              4. Recommended fix approach (concrete steps)
              5. Test plan to verify the fix
              6. Risks / open questions

              End with a short IMPLEMENTATION BRIEF a coding agent can follow.
            EOT
            apiVersion       = "v0"
            repository       = "{{ .outputs.resolve_repo.github_url }}"
            autoCreatePr     = false
            reportCompletion = true
          }
          on_failure = "continue"
        }

        variables = {
          status   = "{{ .result.response.status // .result.status // \"\" }}"
          agentId  = "{{ .result.response.agentId // .result.agentId // \"\" }}"
          summary  = "{{ .result.response.summary // .result.summary // \"Triage completed.\" }}"
          agentUrl = "{{ .result.response.target.url // .result.target.url // \"\" }}"
        }
      },
      {
        identifier  = "cursor_fix"
        title       = "Cursor fix agent"
        icon        = "Cursor"
        description = "Implements the triage brief on branch bugfix/<JIRA-ISSUE> and opens a PR."

        integration_action = {
          installation_id             = "cursor-cloud-agents"
          integration_provider        = "cursor-cloud-agents"
          integration_invocation_type = "create_agent"
          execution_properties = {
            ref = "{{ .outputs.resolve_repo.default_branch // \"develop\" }}"
            config = {
              target = {
                branchName   = "bugfix/{{ .outputs.trigger.diff.after.identifier }}"
                autoCreatePr = true
              }
            }
            prompt           = <<-EOT
              Implement a minimal fix for Jira {{ .outputs.trigger.diff.after.identifier }}.

              Issue title: {{ .outputs.trigger.diff.after.title }}
              Issue URL: {{ .outputs.trigger.diff.after.properties.url }}
              Description:
              {{ .outputs.trigger.diff.after.properties.description }}

              Service: {{ .outputs.resolve_repo.service_title }}
              Repository: {{ .outputs.resolve_repo.github_url }}
              Base ref for the bugfix branch (MUST be this branch, not main): {{ .outputs.resolve_repo.default_branch }}

              Triage agent summary:
              {{ .outputs.cursor_triage.summary }}
              Triage agent URL: {{ .outputs.cursor_triage.agentUrl }}

              Requirements:
              - Create/use branch exactly named bugfix/{{ .outputs.trigger.diff.after.identifier }} cut from {{ .outputs.resolve_repo.default_branch }} (repo default)
              - Do NOT base the branch on main unless default_branch is literally main
              - Before committing, ensure shared dependency files (composer.json/composer.lock, package.json, etc.) include current {{ .outputs.resolve_repo.default_branch }} state
              - Keep the change set minimal and focused on this issue
              - Open a pull request into {{ .outputs.resolve_repo.default_branch }} titled "{{ .outputs.trigger.diff.after.identifier }}: {{ .outputs.trigger.diff.after.title }}"
              - Reference {{ .outputs.trigger.diff.after.identifier }} in the PR body
              - Summarize files changed and the PR URL when done
              - If a suitable open PR already exists for this issue, link it instead of duplicating work
            EOT
            apiVersion       = "v0"
            repository       = "{{ .outputs.resolve_repo.github_url }}"
            autoCreatePr     = true
            reportCompletion = true
          }
          on_failure = "continue"
        }

        variables = {
          prUrl      = "{{ .result.response.target.prUrl // .result.target.prUrl // \"\" }}"
          status     = "{{ .result.response.status // .result.status // \"\" }}"
          agentId    = "{{ .result.response.agentId // .result.agentId // \"\" }}"
          summary    = "{{ .result.response.summary // .result.summary // \"Fix agent completed.\" }}"
          agentUrl   = "{{ .result.response.target.url // .result.target.url // \"\" }}"
          branchName = "{{ .result.response.target.branchName // .result.target.branchName // (\"bugfix/\" + .outputs.trigger.diff.after.identifier) }}"
        }
      },
      {
        identifier = "notify_teams_complete"
        title      = "Notify Teams — triage + PR"
        icon       = "Team"

        webhook = {
          url          = "{{ .secrets[\"TEAMS_WEBHOOK_URL\"] }}"
          method       = "POST"
          agent        = false
          synchronized = true
          headers = {
            "Content-Type" = "application/json"
          }
          body = {
            text       = "**{{ .outputs.trigger.diff.after.identifier }}** — {{ .outputs.trigger.diff.after.title }}\n\nService: {{ .outputs.resolve_repo.service_title }}\nRepo: {{ .outputs.resolve_repo.github_url }}\nBranch: `{{ .outputs.cursor_fix.branchName }}`\n\nTriage: {{ .outputs.cursor_triage.agentUrl }}\nFix agent: {{ .outputs.cursor_fix.agentUrl }}\nPR: {{ .outputs.cursor_fix.prUrl }}\n\nTriage summary:\n{{ .outputs.cursor_triage.summary }}\n\nFix summary:\n{{ .outputs.cursor_fix.summary }}"
            "@type"    = "MessageCard"
            title      = "Cursor triage + fix complete"
            summary    = "Cursor autofix for {{ .outputs.trigger.diff.after.identifier }}"
            "@context" = "http://schema.org/extensions"
            themeColor = "107C10"
          }
          on_timeout = "continue"
          on_failure = "continue"
        }
      },
      {
        identifier = "notify_teams_skipped"
        title      = "Notify Teams — no repo"
        icon       = "Team"

        webhook = {
          url          = "{{ .secrets[\"TEAMS_WEBHOOK_URL\"] }}"
          method       = "POST"
          agent        = false
          synchronized = true
          headers = {
            "Content-Type" = "application/json"
          }
          body = {
            text       = "**{{ .outputs.trigger.diff.after.identifier }}** — {{ .outputs.trigger.diff.after.title }}\n\nCould not resolve a GitHub repository for this SD ticket.\nMatch attempt: {{ .outputs.resolve_repo.match_reason }}\nLinked service: {{ .outputs.trigger.diff.after.relations.service | if type == \"object\" then .identifier else . end }}\n\nLink a service with `github_url` on the Jira issue (or improve title/description) and re-run."
            "@type"    = "MessageCard"
            title      = "Cursor autofix skipped — no GitHub repo"
            summary    = "Cursor autofix skipped for {{ .outputs.trigger.diff.after.identifier }}"
            "@context" = "http://schema.org/extensions"
            themeColor = "D83B01"
          }
          on_timeout = "continue"
          on_failure = "continue"
        }
      },
    ]

    connections = [
      {
        source_identifier = "trigger"
        target_identifier = "move_in_progress"
      },
      {
        source_identifier = "move_in_progress"
        target_identifier = "notify_teams_created"
      },
      {
        source_identifier = "notify_teams_created"
        target_identifier = "resolve_repo"
      },
      {
        source_identifier = "resolve_repo"
        target_identifier = "has_repo"
      },
      {
        source_identifier        = "has_repo"
        target_identifier        = "cursor_triage"
        source_outlet_identifier = "with_repo"
      },
      {
        source_identifier        = "has_repo"
        target_identifier        = "notify_teams_skipped"
        source_outlet_identifier = "without_repo"
      },
      {
        source_identifier = "cursor_triage"
        target_identifier = "cursor_fix"
      },
      {
        source_identifier = "cursor_fix"
        target_identifier = "notify_teams_complete"
      },
    ]
  }
}
