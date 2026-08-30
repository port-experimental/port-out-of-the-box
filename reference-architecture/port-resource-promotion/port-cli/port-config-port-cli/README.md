# port-config

Committed Port export used as the single source of truth for promotion workflows.
Generate or refresh it from a Port org by running the following command from the repository root:

```bash
CONFIG_PATH='reference-architecture/port-resource-promotion/port-cli/port-config-port-cli/port-config.json'
ORG="<your-port-cli-org-slug>"

# No entities, users, or teams
port export --output $CONFIG_PATH --base-org $ORG --format json \
  --include blueprints,scorecards,actions,automations,pages,integrations,blueprint-permissions,action-permissions,page-permissions
```
