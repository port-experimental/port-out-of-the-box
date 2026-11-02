locals {
  jira_close_on_pr_merged = {
    nodes = [
      {
        identifier = "trigger"
        title      = "PR merged callback"
        icon       = "Github"

        self_serve_trigger = {
          published = true
          permissions = {
            roles = ["Admin", "Member"]
          }
          user_inputs = {
            user_properties = {
              string_props = {
                branch = {
                  title = "Head branch"
                }
                pr_url = {
                  title    = "PR URL"
                  format   = "url"
                  required = true
                }
                pr_title = {
                  title = "PR title"
                }
                merge_sha = {
                  title = "Merge commit SHA"
                }
                merged_by = {
                  title = "Merged by"
                }
                pr_number = {
                  title = "PR number"
                }
                repository = {
                  title       = "Repository"
                  description = "GitHub repository full name (org/repo)"
                  required    = true
                }
                merge_status = {
                  title       = "Merge status"
                  description = "Status reported by GitHub Actions"
                  default     = "merged"
                  required    = true
                }
                jira_issue_key = {
                  title       = "Jira issue key"
                  description = "Jira issue key extracted from the branch (e.g. SD-17)"
                  required    = true
                }
              }
            }
            order_properties = [
              "jira_issue_key",
              "repository",
              "pr_number",
              "pr_url",
              "pr_title",
              "branch",
              "merge_sha",
              "merged_by",
              "merge_status",
            ]
          }
        }
      },
      {
        identifier  = "close_jira"
        title       = "Mark Jira issue Done"
        icon        = "Jira"
        description = "Transition the associated SD Jira issue to Done (closed)."

        integration_action = {
          installation_id             = "jira"
          integration_provider        = "jira"
          integration_invocation_type = "change_issue_status"
          execution_properties = {
            status   = "Done"
            issueKey = "{{ .outputs.trigger.jira_issue_key }}"
          }
          on_failure = "terminate"
        }

        variables = {
          status   = "{{ .result.response.status // .result.status // \"Done\" }}"
          issueKey = "{{ .result.response.issueKey // .result.issueKey // .outputs.trigger.jira_issue_key }}"
        }
      },
      {
        identifier  = "comment_jira"
        title       = "Comment merge status on Jira"
        icon        = "Jira"
        description = "Add a Jira comment with the merge/PR status from GitHub Actions."

        webhook = {
          url          = "https://api.atlassian.com/ex/jira/${var.jira_cloud_id}/rest/api/2/issue/{{ .outputs.trigger.jira_issue_key }}/comment"
          method       = "POST"
          agent        = false
          synchronized = true
          headers = {
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer {{ .secrets.__JIRA_JIRA_ATLASSIAN_USER_TOKEN }}"
          }
          body = {
            body = <<-EOT
              Pull request merged — issue closed by Port workflow `jira_close_on_pr_merged`.

              * Status: {{ .outputs.trigger.merge_status }}
              * Jira status set to: {{ .outputs.close_jira.status }}
              * Repository: {{ .outputs.trigger.repository }}
              * Branch: {{ .outputs.trigger.branch }}
              * PR: {{ .outputs.trigger.pr_url }}
              * PR #{{ .outputs.trigger.pr_number }} — {{ .outputs.trigger.pr_title }}
              * Merge SHA: {{ .outputs.trigger.merge_sha }}
              * Merged by: {{ .outputs.trigger.merged_by }}
              * Aikido: related vulnerability will be marked Fixed when a catalog match is found
            EOT
          }
          on_timeout = "fail"
          on_failure = "continue"
        }

        variables = {
          commentId = "{{ .result.response.data.id // .result.response.id // \"\" }}"
        }
      },
      {
        identifier  = "upsert_issue_status"
        title       = "Sync Port jiraIssue status"
        icon        = "Jira"
        description = "Reflect Done status on the Port catalog entity immediately."

        upsert_entity = {
          blueprint_identifier = "jiraIssue"
          on_failure           = "continue"
          mapping = {
            identifier = "{{ .outputs.trigger.jira_issue_key }}"
            properties = {
              status = "Done"
            }
          }
        }
      },
      {
        identifier  = "resolve_aikido"
        title       = "Resolve related Aikido vulnerability"
        icon        = "AI"
        description = "Match the closed Jira/PR to an aikidoVulnerability catalog entity when possible."

        ai = {
          system_prompt = "You match a closed Jira SD issue / merged PR to an aikidoVulnerability Port entity. Prefer a CVE ID extracted from pr_title, branch, or jira key context. Search aikidoVulnerability entities with list_entities. Return only JSON matching the output schema. If no confident match exists, set aikido_identifier to an empty string."
          user_prompt   = <<-EOT
            A bugfix pull request was merged and the related Jira issue was closed.

            Context:
            - Jira issue key: {{ .outputs.trigger.jira_issue_key }}
            - PR title: {{ .outputs.trigger.pr_title }}
            - Branch: {{ .outputs.trigger.branch }}
            - Repository: {{ .outputs.trigger.repository }}
            - PR URL: {{ .outputs.trigger.pr_url }}

            Tasks:
            1. Extract a CVE ID if present in the PR title, branch, or related context.
            2. Search aikidoVulnerability entities for the best match (CVE, title, identifier, related Jira/repo).
            3. Return the matched entity identifier, CVE ID (or empty), and a short match_reason.

            Return JSON fields: aikido_identifier, cve_id, match_reason.
          EOT
          tools = [
            "list_blueprints",
            "list_entities",
          ]
          output_schema = jsonencode({
            type = "object"
            properties = {
              aikido_identifier = {
                type = "string"
              }
              cve_id = {
                type = "string"
              }
              match_reason = {
                type = "string"
              }
            }
            required = ["aikido_identifier", "cve_id", "match_reason"]
          })
        }

        variables = {
          response           = "{{ .result.response }}"
          aikido_identifier  = "{{ (.result.response | if type == \"string\" then fromjson else . end).aikido_identifier // \"\" }}"
          cve_id             = "{{ (.result.response | if type == \"string\" then fromjson else . end).cve_id // \"\" }}"
          match_reason       = "{{ (.result.response | if type == \"string\" then fromjson else . end).match_reason // \"\" }}"
        }
      },
      {
        identifier = "has_aikido"
        title      = "Matched Aikido vulnerability?"
        icon       = "Vulnerability"

        condition = {
          outlets = [
            {
              identifier = "with_aikido"
              title      = "Has Aikido match"
              expression = "(.outputs.resolve_aikido.aikido_identifier // \"\") != \"\""
            },
            {
              identifier = "without_aikido"
              title      = "No Aikido match"
              expression = "(.outputs.resolve_aikido.aikido_identifier // \"\") == \"\""
            },
          ]
        }
      },
      {
        identifier  = "close_aikido"
        title       = "Mark Aikido vulnerability Fixed"
        icon        = "Vulnerability"
        description = "Set the matched aikidoVulnerability status to Fixed after the remediation PR merged."

        upsert_entity = {
          blueprint_identifier = "aikidoVulnerability"
          on_failure           = "continue"
          mapping = {
            identifier = "{{ .outputs.resolve_aikido.aikido_identifier }}"
            properties = {
              status = "Fixed"
            }
          }
        }
      },
    ]

    connections = [
      {
        source_identifier = "trigger"
        target_identifier = "close_jira"
      },
      {
        source_identifier = "close_jira"
        target_identifier = "comment_jira"
      },
      {
        source_identifier = "comment_jira"
        target_identifier = "upsert_issue_status"
      },
      {
        source_identifier = "upsert_issue_status"
        target_identifier = "resolve_aikido"
      },
      {
        source_identifier = "resolve_aikido"
        target_identifier = "has_aikido"
      },
      {
        source_identifier        = "has_aikido"
        target_identifier        = "close_aikido"
        source_outlet_identifier = "with_aikido"
      },
    ]
  }
}
