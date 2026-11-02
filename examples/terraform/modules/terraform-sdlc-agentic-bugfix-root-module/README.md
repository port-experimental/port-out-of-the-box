# terraform-sdlc-autofix-workflows

Composes the `terraform-port-workflow` child module three times to manage the live
Port EU SDLC autofix workflows:

1. `aikido_vuln_cursor_triage_jira` — Aikido vulnerability → Cursor remediation → Jira SD
2. `jira_sd_teams_cursor_autofix` — Jira SD → Teams → Cursor triage → Cursor fix
3. `jira_close_on_pr_merged` — GitHub Actions callback → close Jira + sync Port entity

## Architecture

```text
Pipeline environment variables
  └── Port provider
        └── terraform-port-workflow child module (×3)
              ├── aikido_vuln_cursor_triage_jira
              ├── jira_sd_teams_cursor_autofix
              └── jira_close_on_pr_merged
```

The root owns provider configuration and the three workflow definitions (`data_*.tf`).
The child module owns each `port_workflow` resource.

Child module source:

```text
github.com/port-experimental/terraform-port-workflow?ref=1.0.2
```

## Prerequisites

- Terraform >= 1.5
- `port-labs/port-labs` provider >= 2.33.2 (pinned in `.terraform.lock.hcl`)
- Port EU credentials with permission to manage workflows, supplied as environment
  variables. These are managed externally (for example in your CI/CD secret store)
  and are not Terraform variables:

  | Environment variable | Description |
  | -------------------- | ----------- |
  | `PORT_CLIENT_ID`     | Port client ID used to authenticate the Terraform provider. |
  | `PORT_CLIENT_SECRET` | Port client secret used to authenticate the Terraform provider. |

- Port secrets used by the live workflows (`TEAMS_WEBHOOK_URL`, Jira Atlassian token)
- Integrations: `cursor-cloud-agents`, `jira`
- Blueprints: `aikidoVulnerability`, `service`, `jiraIssue`

## Configuration

```hcl
module "aikido_vuln_cursor_triage_jira" {
  source = "github.com/port-experimental/terraform-port-workflow?ref=1.0.2"

  identifier  = "aikido_vuln_cursor_triage_jira"
  category    = "Security"
  nodes       = local.aikido_vuln_cursor_triage_jira.nodes
  connections = local.aikido_vuln_cursor_triage_jira.connections
}

module "jira_sd_teams_cursor_autofix" {
  source = "github.com/port-experimental/terraform-port-workflow?ref=1.0.2"

  identifier  = "jira_sd_teams_cursor_autofix"
  category    = var.category
  nodes       = local.jira_sd_teams_cursor_autofix.nodes
  connections = local.jira_sd_teams_cursor_autofix.connections
}

module "jira_close_on_pr_merged" {
  source = "github.com/port-experimental/terraform-port-workflow?ref=1.0.2"

  identifier  = "jira_close_on_pr_merged"
  category    = var.category
  nodes       = local.jira_close_on_pr_merged.nodes
  connections = local.jira_close_on_pr_merged.connections
}
```

Workflow identifiers match the live Port EU workflows, which have already been
imported into state. To manage them from a fresh state, import them first:

```bash
terraform import module.aikido_vuln_cursor_triage_jira.port_workflow.main aikido_vuln_cursor_triage_jira
terraform import module.jira_sd_teams_cursor_autofix.port_workflow.main jira_sd_teams_cursor_autofix
terraform import module.jira_close_on_pr_merged.port_workflow.main jira_close_on_pr_merged
```

## Usage

```bash
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...

terraform init
terraform validate
terraform plan
```

State is local by default. `provider.tf` contains a commented-out S3 backend
(`encrypt` and `use_lockfile` enabled); uncomment it and set the bucket, key and
region to store state remotely, then run `terraform init -migrate-state`.

Use `terraform init -upgrade` only when deliberately bumping the provider, and commit
the updated `.terraform.lock.hcl`.

## Inputs

- `jira_cloud_id` — Atlassian cloud ID of the Jira site (required). Find it at
  `https://<your-site>.atlassian.net/_edge/tenant_info`.
- `category` — Default category for the Jira workflows (max 40 characters). Defaults to `Engineering`.
  The Aikido workflow uses `Security` explicitly.

## Outputs

- `aikido_vuln_cursor_triage_jira_id` / `_identifier`
- `jira_sd_teams_cursor_autofix_id` / `_identifier`
- `jira_close_on_pr_merged_id` / `_identifier`
