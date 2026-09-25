# terraform-port-integration

Creates a Port integration installation with the `port_integration` resource. It deliberately contains no provider configuration or credentials; callers supply both from their root module.

> [!CAUTION]
> **Credentials** Do not pass secret values through this module. Anything supplied in `spec` is written to Terraform state in plain text, readable by anyone with access to the state file or to a plan derived from it, regardless of whether the variable is marked `sensitive`. Reference a credential by name so that Terraform only directs the integration at Port's internal credentials store, and manage the credential itself externally.

> [!IMPORTANT]
> **Two-step provisioning** `config` cannot be set on creation. Integrations receive default mappings during provisioning, so the mapping has to be applied as a second, separate `apply`:
>
> 1. Set `config = null` and run `terraform apply` to create the integration.
> 2. Set `config` to your mapping and run `terraform apply` again to override the defaults.
>
> Setting `config` in the same apply that creates the integration fails with:
>
> ```
> Error: config cannot be set on creation
>
>   with module.sample-integration.port_integration.main,
>   on .terraform/modules/sample-integration/main.tf line 1, in resource "port_integration" "main":
>    1: resource "port_integration" "main" {
> ```
>
> This affects anything that builds the integration from scratch, including CI pipelines and any `terraform destroy` followed by a rebuild — a single pipeline run cannot both create the integration and apply its mapping.

## Requirements

- Terraform >= 1.16
- `port-labs/port-labs` provider >= 2.28.0
- Port credentials, supplied either as the `PORT_CLIENT_ID` and `PORT_CLIENT_SECRET` variables or, preferably, as environment variables of the same name in the pipeline

## Usage

```hcl
module "sample-integration" {
  source = "github.com/port-experimental/terraform-port-integration?ref=v1.0.0"

  title                 = "sample-integration"
  installation_id       = "sample-integration-prod"
  installation_app_type = "linear"
  installation_type     = "Saas"

  spec   = local.spec
  config = null //local.config
  //Integrations receive default mappings during provisioning. Create the integration first (without config), then add config to your HCL and run 'terraform apply' again to override the defaults.
}
```

`spec` and `config` are JSON strings. Define them as locals in the calling root module and pass them through bare — the `jsonencode` belongs in the local, not at the call site, or the value is encoded twice and Port receives a quoted string rather than an object:

```hcl
locals {
  spec = jsonencode({
    integrationSpec = {
      linearApiKey = var.api_key_name
    }
  })

  config = jsonencode({
    resources = [
      {
        kind = "issue"
        selector = {
          query = "true"
        }
        port = {
          entity = {
            mappings = {
              identifier = ".identifier"
              blueprint  = "\"linearIssue\""
              title      = ".title"
              properties = {
                url      = ".url"
                status   = ".state.name"
                priority = ".priorityLabel"
              }
            }
          }
        }
      }
    ]
  })
}
```

The example maps Linear issues to a `linearIssue` blueprint, carrying the issue URL, state name and priority label across as properties. The blueprint must already exist in Port, and the JQ expressions on the right-hand side are evaluated by the integration at sync time — a bad expression surfaces in the integration's logs in Port rather than as a Terraform error.

`api_key_name` is the name of a credential in Port, not the key itself. Create the credential out of band — through the Port UI, API, or an existing secrets workflow — and reference it here.

## Variables

- `title` — Title displayed in Port for the integration. Defaults to `sample-integration`.
- `installation_id` — Unique identifier for the integration installation in Port. Defaults to `sample-integration-prod`.
- `installation_app_type` — The integration's app type, such as `linear`, `jira` or `github`. Defaults to `linear`.
- `installation_type` — How the integration is hosted. Defaults to `Saas`; validated against `Saas` and `OnPrem`.
- `api_key_name` — Name of the credential in Port's internal credentials store holding the integration's API key. Defaults to `integration-api-key`. The key value itself is managed outside Terraform.
- `PORT_CLIENT_ID` — Port client ID. Sensitive; defaults to `null`. Prefer supplying this through CI secrets.
- `PORT_CLIENT_SECRET` — Port client secret. Sensitive; defaults to `null`. Prefer supplying this through CI secrets.

`spec` and `config` are not variables — they are built as locals in this module and passed to the child module directly.

## Module arguments

The child module accepts `title`, `installation_id`, `installation_app_type`, `installation_type`, `spec` and `config`. Only `installation_id` is required; the rest default to `null`.

## Outputs

- `id` — Port's internal identifier for the integration resource.
- `title` — Title displayed in Port.
- `installation_id` — Installation identifier of the integration.
- `installation_app_type` — App type of the integration.
- `installation_type` — Hosting type of the integration.
- `config` — Mapping configuration applied to the integration. `null` until the second apply; see the two-step note above.

`spec` is not exported. It is the field most likely to carry credential references, and outputs propagate into state and into any consuming module. Add it with `sensitive = true` if a downstream module needs it.