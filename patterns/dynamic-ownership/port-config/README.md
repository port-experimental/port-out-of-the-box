# Port configuration

What the [dynamic ownership pattern](../README.md) creates in Port, and the ways to apply it. The [guide](../GUIDE.md#2-port-extend-the-blueprints) has the commands.

| Folder | What it is |
|---|---|
| [`definitions/`](definitions) | The Port objects as JSON: blueprint additions, workflows, and dashboards. These files do not depend on any tool. An agent or a script can apply them through the Port API. |
| [`port-cli/`](port-cli) | `apply.sh`, which applies the definitions with the Port CLI. It can create everything the pattern needs. |
| [`terraform/`](terraform) | The same objects as Terraform. Blueprints and workflows are written as HCL. The dashboards are read from `definitions/`. |

## Choose how to apply

Use **one** of `port-cli/` or `terraform/` for an organization. Neither one needs the other, and you do not need Terraform at all. If you use neither, apply the files in `definitions/` through the Port API.

Do not apply both to the same organization.

## Keeping them in step

- The dashboards have one copy, in `definitions/pages`. Terraform reads it from there, so copy `definitions/` along with `terraform/` if you lift the module out of this repository.
- Terraform's HCL for blueprints and workflows expresses the same objects as `definitions/blueprints` and `definitions/workflows`. The provider models workflow nodes as typed blocks and cannot read the JSON directly, so a change to one needs the same change in the other.
