# Dynamic ownership: Port CLI

Applies the Port side of the [dynamic ownership pattern](../../README.md) with the [Port CLI](https://docs.port.io/). One script applies the JSON files in [`../definitions`](../definitions). There is no state to manage, and you can run the script again at any time. The [guide](../../GUIDE.md#2-port-extend-the-blueprints) has the commands. This file is the reference.

You do not need Terraform for this. The CLI creates everything the pattern needs. See [`port-config`](..) for how this folder relates to [`../terraform`](../terraform): use one of the two.

The adapter is separate. See [`adapters/github-sync`](../../adapters/github-sync).

## What the script applies

`apply.sh` applies these files from [`../definitions`](../definitions), in order. It supports `--dry-run` and `--with-pages`.

| Path in `definitions/` | Contents |
|---|---|
| `blueprints/team.json`, `user.json` | Properties, relation, mirror and aggregation added to the built-in `_team` and `_user` blueprints |
| `blueprints/service.additions.json` | What is added to your service blueprint: staging relation, mirror property, Direct ownership |
| `blueprints/service.minimal.json` | A minimal service blueprint, used only when you ask the script to create one |
| `blueprints/ownership_change.json` | The audit blueprint |
| `workflows/` | The seven workflows |
| `pages/` | The four dashboards, applied only with `--with-pages` |

`apply.sh` **merges** into the built-in `_team` and `_user` blueprints and into your service blueprint. It reads the current definition, adds what the pattern needs, and writes the result back. Existing properties, relations and ownership settings are kept. The `ownership_change` blueprint, the workflows and the pages are upserted.

## Requirements

- The [Port CLI](https://docs.port.io/) and `jq` on your path.
- Port client credentials.
- A service blueprint with **Direct ownership**. The script adds Direct ownership when the blueprint has none, and leaves any existing setting alone. If your blueprint uses Inherited ownership, the pattern will not work.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `PORT_CLIENT_ID`, `PORT_CLIENT_SECRET` | required | Port credentials |
| `PORT_API_URL` | `https://api.port.io/v1` | Port API, including `/v1`. Use `https://api.us.port.io/v1` for a US organization |
| `SERVICE_BLUEPRINT` | `service` | Blueprint that swarms are linked to |
| `CREATE_SERVICE_BLUEPRINT` | `false` | Set to `true` to create the service blueprint if it does not exist. Only for new or sandbox organizations |
| `REQUESTOR_TEAMS` | none | Comma-separated team identifiers that can run the forms, in addition to the Admin role |

## Notes

- **Order matters.** Blueprints are applied before workflows, and workflows before pages, because each refers to the one before.
- **Pages are optional.** Port validates each page definition when it is written. Apply the pages in a sandbox organization before production.
- **Placeholders.** The JSON files use `__SERVICE_BLUEPRINT__` for the service blueprint identifier. The script replaces it. If you apply the files some other way, replace it yourself.
- **Terraform equivalent.** [`../terraform`](../terraform) defines the same resources for customers who use Terraform. Use one of the two. The dashboards are shared, and the blueprints and workflows are kept in step by hand.
