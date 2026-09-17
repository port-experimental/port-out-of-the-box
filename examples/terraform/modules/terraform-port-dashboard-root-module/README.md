# terraform-port-dashboard-root-module

Composes the `terraform-port-dashboard` child module and configures the Port provider for two dashboard deployments: a starter dashboard and an Ocean integration dashboard.

> [!CAUTION]
> **Beta features**
> Port dashboard pages require `PORT_BETA_FEATURES_ENABLED=true` in the Terraform pipeline environment. Use this root module first in a non-production Port organization, pin the provider version in `provider.tf`, and inspect `terraform plan` before applying.

## Architecture

```text
Pipeline environment variables
  └── Port provider
        └── terraform-port-dashboard child module
              └── Port dashboard page and widgets
```

The root owns provider configuration and credentials. The child module owns only the `port_page` resource.

## Prerequisites

- Terraform >= 1.16
- Port provider >= 2.25.0
- `PORT_CLIENT_ID`, `PORT_CLIENT_SECRET`, and `PORT_BETA_FEATURES_ENABLED=true` available as protected pipeline environment variables
- A valid widget definition in `data.tf`

## Configuration

The starter dashboard passes metadata from root variables and widgets from `local.sample_dashboard.widgets`:

```hcl
module "sample-dashboard" {
  source = "git::https://github.com/port-experimental/terraform-port-dashboard.git?ref=1.0.0"

  identifier  = var.identifier
  title       = var.title
  description = var.description
  locked      = var.locked
  icon        = var.icon
  widgets     = [local.sample_dashboard.widgets]
  parent      = var.parent
}
```

The Ocean integration dashboard uses the same child module with its fixed identifier and widgets from `local.ocean_integrations.widgets`.

## Inputs

- `identifier` — Dashboard identifier. Defaults to `dashboard`.
- `title` — Dashboard title. Defaults to `Terraform created dashboard`.
- `description` — Optional dashboard description.
- `locked` — Whether the page is locked. Defaults to `true`.
- `icon` — Optional Port icon.
- `parent` — Optional parent page identifier.

`PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` authenticate the Port provider. `PORT_BETA_FEATURES_ENABLED=true` enables dashboard-page support. Set all three through the pipeline environment; do not use `.tfvars` files or commit credentials.

## Outputs

- `identifier` — Created dashboard identifier.
- `parent` — Assigned parent page.
- `created_at`, `created_by`, `updated_at`, and `updated_by` — Port audit metadata.
