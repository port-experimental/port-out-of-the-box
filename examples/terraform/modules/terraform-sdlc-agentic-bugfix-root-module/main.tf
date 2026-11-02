module "aikido_vuln_cursor_triage_jira" {
  source = "github.com/port-experimental/terraform-port-workflow?ref=1.0.2"

  identifier                = "aikido_vuln_cursor_triage_jira"
  title                     = "Aikido Vulnerability → Cursor Triage → Jira SD"
  icon                      = "Vulnerability"
  description               = "When an Aikido vulnerability is created, resolve the impacted service, run a Cursor cloud agent to triage and open a remediation PR when possible, and open a Jira ticket in SD with impact and severity."
  category                  = "Agentic Triage"
  allow_anyone_to_view_runs = true
  nodes                     = local.aikido_vuln_cursor_triage_jira.nodes
  connections               = local.aikido_vuln_cursor_triage_jira.connections
}

module "jira_sd_teams_cursor_autofix" {
  source = "github.com/port-experimental/terraform-port-workflow?ref=1.0.2"

  identifier                = "jira_sd_teams_cursor_autofix"
  title                     = "Jira SD → Teams → Cursor Triage → Fix"
  icon                      = "Jira"
  description               = "When a Jira issue is created on the SD board, move it to In Progress, notify a Microsoft Teams channel, run a Cursor cloud agent to triage the issue, then run a second Cursor cloud agent to implement a fix on branch bugfix/<JIRA-ISSUE> and open a GitHub PR."
  category                  = var.category
  allow_anyone_to_view_runs = true
  nodes                     = local.jira_sd_teams_cursor_autofix.nodes
  connections               = local.jira_sd_teams_cursor_autofix.connections
}

module "jira_close_on_pr_merged" {
  source = "github.com/port-experimental/terraform-port-workflow?ref=1.0.2"

  identifier                = "jira_close_on_pr_merged"
  title                     = "Close Jira on PR Merge"
  icon                      = "Jira"
  description               = "Called from GitHub Actions when a bugfix/* pull request is merged. Transitions the associated Jira issue to Done and comments the merge status (PR URL, branch, SHA, merger)."
  category                  = var.category
  allow_anyone_to_view_runs = true
  nodes                     = local.jira_close_on_pr_merged.nodes
  connections               = local.jira_close_on_pr_merged.connections
}

module "agentic_fix_velocity_dashboard" {
  source = "git::https://github.com/port-experimental/terraform-port-dashboard.git?ref=1.0.0"

  identifier  = "agentic_fix_velocity"
  title       = "Agentic Fix Velocity"
  description = "Discovery-to-fix velocity for the agentic bugfix pipeline (Aikido → Jira SD → Cursor → Done), aligned to DORA throughput, lead time, and recovery guidance."
  icon        = "Health"
  locked      = false
  parent      = var.dashboard_parent
  widgets     = [file("${path.module}/dashboards/agentic_fix_velocity.json")]
}
