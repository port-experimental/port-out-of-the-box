# Dynamic ownership: Terraform

Installs the [dynamic ownership pattern](../README.md) into a Port organization with the [Port Terraform provider](https://registry.terraform.io/providers/port-labs/port-labs/latest/docs). This is a root module: run it directly, or lift the files into your own Terraform.

Add the [GitHub sync](../github-sync) separately. It is a GitHub Action, not Terraform.

## What it creates

| File | Resources |
|---|---|
| `blueprints.tf` | Extends `_team` and `_user` (`port_system_blueprint`), the `size` aggregation on `_team` (`port_aggregation_properties`), the `ownership_change` blueprint, and optionally a minimal service blueprint |
| `workflows.tf` | The seven workflows (`port_workflow`) |
| `pages.tf` | The four dashboards (`port_page`), only when `create_pages = true` |

The built-in properties of `_team` and `_user` are not managed. Only the properties listed in `blueprints.tf` are added.

## Prerequisites

- Terraform 1.5 or later (validated and planned with 1.16) and the `port-labs/port-labs` provider 2.36.2 or later (the version this was planned with).
- Port client credentials, passed as `PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` environment variables.
- A service blueprint with **Direct ownership**. See [Your service blueprint](#your-service-blueprint).

## Use it

```bash
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...

terraform init
terraform plan  -var 'service_blueprint_identifier=service'
terraform apply -var 'service_blueprint_identifier=service'
```

Review the plan before you apply it. Run it in a sandbox organization first, as the checks in the [pattern README](../README.md#try-it) describe.

| Variable | Default | Purpose |
|---|---|---|
| `service_blueprint_identifier` | `service` | Blueprint that swarms are linked to |
| `create_service_blueprint` | `false` | Create a minimal service blueprint. Only for new or sandbox organizations |
| `workflow_requestor_roles` | `["Admin"]` | Roles that can run the swarm forms |
| `workflow_requestor_teams` | `[]` | Existing team identifiers that can also run the forms |
| `create_pages` | `false` | Create the four dashboards |
| `port_base_url` | provider default | API base URL, without `/v1`. Set it for other regions, for example `https://api.us.port.io` or `https://api.us.getport.io` |

Store state in a remote backend such as Terraform Cloud, as you would for any shared Terraform. This module does not configure one.

## Your service blueprint

The workflows need three things on the blueprint that represents your services. The module creates them only when `create_service_blueprint = true`, because Terraform cannot add to a blueprint that another configuration or the UI owns.

If you already have a service blueprint, add these to it yourself:

```hcl
# In your existing port_blueprint for services:

ownership = {
  type = "Direct"
}

relations = {
  pending_swarm = {
    title    = "Pending swarm"
    target   = "_team"
    required = false
    many     = false
  }
}

mirror_properties = {
  pending_swarm_parent = {
    title = "Pending swarm parent"
    path  = "pending_swarm.parent_team.$identifier"
  }
}
```

Alternatively, run the [`port-cli`](../port-cli) script for that one step: it merges these into an existing blueprint without replacing anything.

Apply this change before the workflows, because they reference the relation.

## Notes

- **Append template.** `apply_pending_swarm` and `apply_pending_owner` append to a list. They do it through a template in the entity mapping's `teams` argument, which the provider documents as accepting `{{ }}` expressions. The same logic is defined as plain JSON in [`../port-cli/workflows`](../port-cli/workflows). After your first apply, run the checks in the pattern README and confirm that a user's and a service's existing teams are kept.
- **Pages.** The files in `pages/` are the same as `../port-cli/pages/`. If you change one copy, change the other.
- **Service dependency.** The workflows that touch the service blueprint depend on `port_blueprint.service`. That resource has a count of zero unless `create_service_blueprint` is true, so Terraform does not wait on anything when you bring your own.
