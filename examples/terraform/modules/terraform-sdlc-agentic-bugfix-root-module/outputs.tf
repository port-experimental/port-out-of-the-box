output "aikido_vuln_cursor_triage_jira_id" {
  description = "Port workflow identifier for aikido_vuln_cursor_triage_jira."
  value       = module.aikido_vuln_cursor_triage_jira.id
}

output "aikido_vuln_cursor_triage_jira_identifier" {
  description = "Configured identifier for aikido_vuln_cursor_triage_jira."
  value       = module.aikido_vuln_cursor_triage_jira.identifier
}

output "jira_sd_teams_cursor_autofix_id" {
  description = "Port workflow identifier for jira_sd_teams_cursor_autofix."
  value       = module.jira_sd_teams_cursor_autofix.id
}

output "jira_sd_teams_cursor_autofix_identifier" {
  description = "Configured identifier for jira_sd_teams_cursor_autofix."
  value       = module.jira_sd_teams_cursor_autofix.identifier
}

output "jira_close_on_pr_merged_id" {
  description = "Port workflow identifier for jira_close_on_pr_merged."
  value       = module.jira_close_on_pr_merged.id
}

output "jira_close_on_pr_merged_identifier" {
  description = "Configured identifier for jira_close_on_pr_merged."
  value       = module.jira_close_on_pr_merged.identifier
}
