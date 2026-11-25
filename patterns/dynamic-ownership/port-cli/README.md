# Dynamic ownership: Port CLI

Installs the [dynamic ownership pattern](../README.md) into a Port organization with the [Port CLI](https://docs.port.io/). The definitions are plain JSON, and one script applies them. There is no state to manage, and you can run the script again at any time.

Add the [GitHub sync](../github-sync) separately. It is a GitHub Action, not part of this script.

## What is in here

| Path | Contents |
|---|---|
| `apply.sh` | Applies everything below, in order. Supports `--dry-run` and `--with-pages` |
| `blueprints/team.json`, `user.json` | Properties, relation, mirror and aggregation added to the built-in `_team` and `_user` blueprints |
| `blueprints/service.additions.json` | What is added to your service blueprint: staging relation, mirror property, Direct ownership |
| `blueprints/service.minimal.json` | A minimal service blueprint, used only when you ask the script to create one |
| `blueprints/ownership_change.json` | The audit blueprint |
| `workflows/` | The seven workflows |
| `pages/` | The four dashboards, applied only with `--with-pages` |

`apply.sh` **merges** into the built-in `_team` and `_user` blueprints and into your service blueprint. It reads the current definition, adds what the pattern needs, and writes the result back. Existing properties, relations and ownership settings are kept. The `ownership_change` blueprint, the workflows and the pages are upserted.

## Prerequisites

- The [Port CLI](https://docs.port.io/) and `jq` on your path.
- Port client credentials.
- A service blueprint with **Direct ownership**. The script adds Direct ownership when the blueprint has none, and leaves any existing setting alone. If your blueprint uses Inherited ownership, the pattern will not work.

## Use it

```bash
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...
export PORT_API_URL=https://api.port.io/v1     # or https://api.us.port.io/v1 for a US organization

./apply.sh --dry-run        # shows what would change
./apply.sh                  # blueprints and workflows
./apply.sh --with-pages     # also the four dashboards
```

| Variable | Default | Purpose |
|---|---|---|
| `PORT_CLIENT_ID`, `PORT_CLIENT_SECRET` | required | Port credentials |
| `PORT_API_URL` | `https://api.port.io/v1` | Port API, including `/v1` |
| `SERVICE_BLUEPRINT` | `service` | Blueprint that swarms are linked to |
| `CREATE_SERVICE_BLUEPRINT` | `false` | Set to `true` to create the service blueprint if it does not exist. Only for new or sandbox organizations |
| `REQUESTOR_TEAMS` | none | Comma-separated team identifiers that can run the forms, in addition to the Admin role |

Run it in a sandbox organization first, and then run the checks in the [pattern README](../README.md#try-it).

## Notes

- **Order matters.** Blueprints are applied before workflows, and workflows before pages, because each refers to the one before.
- **Pages are optional.** Port validates each page definition when it is written. Apply the pages in a sandbox organization before production.
- **Placeholders.** The JSON files use `__SERVICE_BLUEPRINT__` for the service blueprint identifier. The script replaces it. If you apply the files some other way, replace it yourself.
- **Terraform equivalent.** [`../terraform`](../terraform) defines the same resources. The files in `pages/` are shared by both. If you change one copy, change the other.
