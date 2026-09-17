# Port Blueprint Root Module

Example root module that creates a Port blueprint through the local `terraform-port-blueprint` child module.

## Prerequisites

- Terraform 1.x
- Port API credentials with blueprint write permissions

## Authentication

```bash
export TF_VAR_PORT_CLIENT_ID="your-port-client-id"
export TF_VAR_PORT_CLIENT_SECRET="your-port-client-secret"
```

## Run

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

## Structure

- `data.tf` — blueprint definition (`local.sample_blueprint`)
- `main.tf` — child-module invocation
- `provider.tf` — Port provider configuration
- `variables.tf` — credential variables

Every optional field referenced from `main.tf` must exist in the local object. Use `{}` for empty maps and `null` for unused optional values.

Before sharing this root module, replace its absolute child-module source path with a relative or versioned Git source. Use remote state for shared or CI use. Never commit state or credentials.

## References

- [Port Blueprint resource documentation](https://registry.terraform.io/providers/port-labs/port-labs/latest/docs/resources/blueprint)
- [Port Terraform provider](https://registry.terraform.io/providers/port-labs/port-labs/latest/docs)
