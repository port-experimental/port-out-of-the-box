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
    ]
  }
}
