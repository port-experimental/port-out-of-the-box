# terraform

Committed Port Terraform module used as the single source of truth for promotion workflows. Generate `generated.tf` from a Port org, bootstrap Integration state in Terraform Cloud, then promote only resource declarations.

CI requires `generated.tf`. Until it exists, plan/apply jobs fail fast so an empty scaffold cannot accidentally manage a live Port org.

The `cd terraform` in the command blocks below assumes this module sits one level below your working directory — adjust it to wherever this directory actually lives.

## Bootstrap (one-time, before enabling promotion)

Use [`terraform-import-generator`](https://github.com/port-experimental/terraform-import-generator) against your Integration org.

Keep `providers.tf` and `terraform.tf` in place. Prefer generating imports **without** `--terraform` when those files already exist; drive `terraform init` / `plan -generate-config-out` yourself so the generator cannot overwrite `providers.tf` with a conflicting default.

The module's local provider name is **`port-labs`** (generator default). That matches what `terraform plan -generate-config-out` emits, so `generated.tf` needs no provider-name rewrite. Do **not** pass `--provider-alias port`.

### Port API URL

Use **`PORT_BASE_URL`** everywhere in this repo (Terraform provider, CI, auth checks). No `/v1` suffix.

| Region | `PORT_BASE_URL` |
|--------|-----------------|
| US (`app.us.port.io`) | `https://api.us.port.io` |
| EU (`app.port.io`) | `https://api.port.io` |

[`terraform-import-generator`](https://github.com/port-experimental/terraform-import-generator) is the exception: its API client reads **`PORT_API_BASE_URL`**, not `PORT_BASE_URL`.

```bash
cd terraform

export PORT_CLIENT_ID=...          # Integration org machine user
export PORT_CLIENT_SECRET=...
export PORT_BETA_FEATURES_ENABLED=true
export PORT_BASE_URL=https://api.us.port.io   # or https://api.port.io for EU

# Import generator only (see Port API URL above):
export PORT_API_BASE_URL="${PORT_BASE_URL}"
port-tf-import -m --auto-fix --report --generate-fix-script

# See Troubleshooting:
# terraform init fails on a duplicate import for port_system_blueprint._team

# The workspace must already exist with execution_mode=local — one auto-created
# by terraform init would default to remote execution. Easiest way: run the
# pipeline once via workflow_dispatch. It creates
# ${TFC_WORKSPACE_SLUG}-integration, then fails with a bootstrap notice, which
# is expected until generated.tf is committed. Creating it by hand in Terraform
# Cloud works too. Only integration can be provisioned this way: staging and
# production are restricted to release tags, so their workspaces are created by
# the first release run.

# Partial cloud {} in terraform.tf needs these for local init.
# TF_WORKSPACE must match ${TFC_WORKSPACE_SLUG}-integration from the workflow env.
# PORT_* above must still be set in this shell for plan/apply.
export TF_CLOUD_ORGANIZATION=...       # match GitHub Environment ${TFC_ORGANIZATION}
export TF_WORKSPACE=...                # ${TFC_WORKSPACE_SLUG}-${ENVIRONMENT}, e.g. port-config-integration
export TF_TOKEN_app_terraform_io=...   # workspace-scoped team token preferred

terraform init
terraform plan -generate-config-out=generated.tf

# Once generated.tf exists:
./fix_generated.sh

# Terraform forbids `provider = …` on import blocks.
# strip those lines from all *_imports.tf before apply:
# sed -i '' '/^[[:space:]]*provider[[:space:]]*=/d' *_imports.tf

# Import existing resources into TFC state
terraform apply

# Cleanup: *_imports.tf, fix_generated.sh, migration_report.md
rm -f *_imports.tf fix_generated.sh migration_report.md
```

## Local development

```bash
cd terraform
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...
export PORT_BETA_FEATURES_ENABLED=true
export PORT_BASE_URL=https://api.us.port.io   # or https://api.port.io for EU
export PORT_API_BASE_URL="${PORT_BASE_URL}"   # required by import-generator
export TF_CLOUD_ORGANIZATION=...
export TF_WORKSPACE=...
export TF_TOKEN_app_terraform_io=...

terraform init
terraform plan
```

## Troubleshooting

### Duplicate import for `port_system_blueprint._team`

`terraform init` right after generating imports may fail with:

```
│ Error: Duplicate import configuration for "port_system_blueprint._team"
│
│   on scorecard_imports.tf line 2, in import:
│    2:   to = port_system_blueprint._team
│
│ An import block for the resource "port_system_blueprint._team" was already declared at blueprint_imports.tf:31,1-7. A resource can have only one import block.
```

[`terraform-import-generator`](https://github.com/port-experimental/terraform-import-generator) writes `port_system_blueprint._team` into `blueprint_imports.tf`, then writes it again at the top of `scorecard_imports.tf` when scorecards reference `_team`. Terraform allows only one `import` block per resource address.

**Fix manually**

1. Open `scorecard_imports.tf` and delete the `_team` import block at the top (leave every `port_scorecard.*` block below it).
2. Leave `blueprint_imports.tf` unchanged — that file keeps the canonical `_team` import.
3. Re-run `terraform init` and continue the bootstrap sequence.

**Sample prompt**

> `terraform init` fails with duplicate import for `port_system_blueprint._team` in `scorecard_imports.tf` and `blueprint_imports.tf`. Remove the duplicate from `scorecard_imports.tf` and keep the `port_scorecard.*` imports.
