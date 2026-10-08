# Incident Auto-Triage Workflow

Deploys the existing Port workflow `incident-auto-triage` with the shared
`terraform-port-workflow` child module.

Members select an `incident` entity, then Port AI uses the Port context lake and the
Notion MCP server to prepare a structured triage summary. The workflow posts the
summary and severity to `#incidents` through the Slack Web API.

## Prerequisites

- An `incident` blueprint in Port.
- A Port Notion MCP server with identifier `notion`.
- A workflow secret named `SLACK_BOT_TOKEN`, authorized to call Slack
  `chat.postMessage` in `#incidents`.
- Provider credentials supplied through `PORT_CLIENT_ID` and
  `PORT_CLIENT_SECRET`, or the matching Terraform variables.

## Adoption

`imports.tf` imports the existing `incident-auto-triage` workflow on the first
`terraform apply`, avoiding recreation of the live workflow.
