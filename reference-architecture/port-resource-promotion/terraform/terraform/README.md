# terraform

Committed Port Terraform module used as the single source of truth for promotion workflows. Generate `generated.tf` from a Port org, bootstrap Integration state in Terraform Cloud, then promote only resource declarations.

CI requires `generated.tf`. Until it exists, plan/apply jobs fail fast so an empty scaffold cannot accidentally manage a live Port org.

The `cd terraform` in the command blocks below assumes this module sits one level below your working directory — adjust it to wherever this directory actually lives.

## Bootstrap (one-time, before enabling promotion)

Use [`terraform-import-generator`](https://github.com/port-experimental/terraform-import-generator) against your Integration org.

Keep `providers.tf` and `terraform.tf` in place. Prefer generating imports **without** `--terraform` when those files already exist; drive `terraform init` / `plan -generate-config-out` yourself so the generator cannot overwrite `providers.tf` with a conflicting default.

The module's local provider name is **`port-labs`** (generator default). That matches what `terraform plan -generate-config-out` emits, so `generated.tf` needs no provider-name rewrite. Do **not** pass `--provider-alias port`.

```bash
cd terraform

export PORT_CLIENT_ID=...          # Integration org machine user
export PORT_CLIENT_SECRET=...
export PORT_BETA_FEATURES_ENABLED=true
# Generator auth host (defaults to EU api.getport.io if unset):
export PORT_API_BASE_URL=https://api.us.port.io
# Provider / other tooling (defaults to US in CI; set EU override if needed):
# export PORT_BASE_URL=https://api.port.io

# Generate imports + report only — do not pass --terraform when providers.tf exists.
# Optional: --generate-fix-script for jq/expression quirks only (not provider names).
port-tf-import -m --auto-fix --report --generate-fix-script

# Known generator quirk: scorecard_imports.tf may also declare
# port_system_blueprint._team (already in blueprint_imports.tf). Delete the
# scorecard copy before terraform init, or init will fail on duplicate import.

# Partial cloud {} in terraform.tf needs these for local init.
# TF_WORKSPACE must match ${TFC_WORKSPACE_SLUG}-integration from the workflow env.
export TF_CLOUD_ORGANIZATION=...
export TF_WORKSPACE=...            # e.g. ${TFC_WORKSPACE_SLUG}-integration
export TF_TOKEN_app_terraform_io=...   # workspace-scoped team token preferred

terraform init
terraform plan -generate-config-out=generated.tf

# Once generated.tf exists, Terraform forbids `provider = …` on import blocks.
# Strip those lines from all *_imports.tf before apply:
sed -i '' '/^[[:space:]]*provider[[:space:]]*=/d' *_imports.tf

# Optional: ./fix_generated.sh if generated (jq_condition etc.)
terraform apply          # imports existing Integration resources into TFC state
rm -f *_imports.tf fix_generated.sh migration_report.md
# Do not commit *_imports.tf, migration_report.md, or fix_generated.sh
```

## Local development

```bash
cd terraform
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...
export PORT_BETA_FEATURES_ENABLED=true
export PORT_BASE_URL=https://api.us.port.io   # or https://api.port.io for EU
export TF_CLOUD_ORGANIZATION=...
export TF_WORKSPACE=...
export TF_TOKEN_app_terraform_io=...

terraform init
terraform plan
```
