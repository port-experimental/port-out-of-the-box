# Dynamic ownership: setup guide

This guide sets up the [dynamic ownership pattern](README.md) in a Port organization. Read the [README](README.md) first for what the pattern is and its limits. The [design notes](docs/design.md) explain how it is built.

Do the first run in a **sandbox organization**, not production.

## Implement with AI

Send this to a coding agent. The agent works from the files in this folder.

**Recommended:** connect the Port MCP server to your agent, so it can read your organization's blueprints and check the prerequisites.

```
You are setting up the dynamic ownership pattern in a Port organization.

Start by reading these files in this folder: README.md (what the pattern is, its requirements and limits), GUIDE.md (this guide), and docs/design.md.

Then follow the numbered steps in GUIDE.md, in order. Rules:

- Before you start, check each item in "Prerequisites" and report which are met. Stop if one is not met.
- Ask me for every value in "Inputs" that I have not given you. Do not guess a value.
- Never ask me to paste a secret into the chat. Tell me to export it as an environment variable (PORT_CLIENT_ID, PORT_CLIENT_SECRET) or to add it as a GitHub secret.
- Use the sandbox Port organization I name. If the organization looks like production, stop and ask me.
- Run each dry run first (terraform plan, or ./apply.sh --dry-run), show me the output, and wait for my go-ahead before each apply.
- Use either port-config/terraform or port-config/port-cli, never both, for the same organization.
- Do not change existing blueprint properties, relations, or workflows beyond what the steps add. If something conflicts, stop and ask.
- Do not run the GitHub sync in apply mode unless I say so.
- Refer to files by their relative path from this folder.
- At the end, run the checks in "Verify" and report each result as pass or fail.
```

## Prerequisites

Check each item before you start.

### Port

- A Port organization, with admin rights to change blueprints. A sandbox organization for the first run.
- Port client credentials: a client ID and client secret.
- A **service blueprint** with **Direct ownership** (the ownership type is Direct, not Inherited). The pattern uses a blueprint called `service` by default. Any name works if you set it as an input.
- Port **users and teams** in the catalog. For the GitHub adapter, each person who should get GitHub access needs `github_login` set on their `_user` entity.

### Customer systems (for the GitHub adapter)

- A GitHub organization you administer.
- A repository you own, to hold the sync workflow.
- One team per repository named `owners-<repo>`, with `CODEOWNERS` pointing at it. Create these yourself. The sync never creates teams.

### Tools

- Either Terraform 1.5 or later, or the Port CLI with `jq`. You need one of them, not both.
- Git, for copying the GitHub adapter into your repository.

## Inputs

| Input | Default | Set it with | Used in |
|---|---|---|---|
| Service blueprint identifier | `service` | Terraform: `service_blueprint_identifier`. CLI: `SERVICE_BLUEPRINT` | Steps 2, 4 |
| Create a service blueprint? | `false` | Terraform: `create_service_blueprint`. CLI: `CREATE_SERVICE_BLUEPRINT` | Step 2, sandbox only |
| Roles and teams that can run the forms | `Admin`, and no teams | Terraform: `workflow_requestor_roles`, `workflow_requestor_teams`. CLI: `REQUESTOR_TEAMS` | Step 2 |
| Create the dashboards? | `false` | Terraform: `create_pages = true`. CLI: `--with-pages` | Step 3 |
| Port API URL | `https://api.port.io/v1` | Terraform: `port_base_url`, without `/v1`. CLI: `PORT_API_URL`, with `/v1` | Step 2 |
| Port client ID and secret | none | Environment variables `PORT_CLIENT_ID`, `PORT_CLIENT_SECRET` | Steps 2, 4 |
| GitHub organization | none | Repository variable `OWNERSHIP_GITHUB_ORG` | Step 4 |
| GitHub App client ID | none | Repository variable `OWNERSHIP_APP_CLIENT_ID` | Step 4 |
| GitHub App installation ID | none | Repository variable `OWNERSHIP_INSTALLATION_ID` | Step 4 |
| GitHub App private key | none | Repository secret `OWNERSHIP_APP_PRIVATE_KEY` | Step 4 |
| Service to sync | none | The `service` input when you run the workflow | Step 4 |
| Repository to sync | none | The `repo` input when you run the workflow | Step 4 |

## 1. Check the prerequisites

Confirm each item under [Prerequisites](#prerequisites).

- In Port, open your service blueprint. Its ownership is Direct.
- In Port, `_team` and `_user` exist, and some `_user` entities have `github_login` set.
- Your sandbox organization is not production.

**Expected:** every item is met. If one is not, fix it before you go on.

## 2. Port: extend the blueprints

Choose **one** of the two. Run the commands from the repository root.

**Option A: Terraform** (in [`port-config/terraform`](port-config/terraform))

```bash
cd patterns/dynamic-ownership/port-config/terraform
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...

terraform init
terraform plan  -var 'service_blueprint_identifier=<your-service-blueprint>'
terraform apply -var 'service_blueprint_identifier=<your-service-blueprint>'
```

If your service blueprint already exists and Terraform does not manage it, first add the relation, the mirror property, and Direct ownership to it. The [Terraform README](port-config/terraform/README.md#your-service-blueprint) has the exact snippet. Then run the plan.

**Option B: Port CLI** (in [`port-config/port-cli`](port-config/port-cli))

```bash
cd patterns/dynamic-ownership/port-config/port-cli
export PORT_CLIENT_ID=...
export PORT_CLIENT_SECRET=...
export PORT_API_URL=https://api.port.io/v1     # or https://api.us.port.io/v1
export SERVICE_BLUEPRINT=<your-service-blueprint>

./apply.sh --dry-run
./apply.sh
```

The CLI script adds the Direct ownership and the staging relation to your service blueprint for you.

**Expected:**
- The `_team` and `_user` blueprints gain the properties listed in [`docs/design.md`](docs/design.md#data-model).
- The `ownership_change` blueprint exists.
- Seven workflows exist: `create_swarm`, `add_user_to_swarm`, `apply_pending_swarm`, `add_swarm_to_service`, `apply_pending_owner`, `log_service_owner_change`, `log_user_team_change`.

Show the dry-run output before you apply.

## 3. Port: add the dashboards (optional)

Dashboards are not required for the pattern to work. They show the state of ownership.

**Terraform:** add `-var 'create_pages=true'` to the apply command.

**Port CLI:** run `./apply.sh --with-pages`.

**Expected:** four pages in Port: Org Structure, My Team, Management, Ownership trail. See [`docs/design.md`](docs/design.md#dashboards-optional).

## 4. Set up the GitHub adapter

This step is specific to GitHub. If your customer manages teams somewhere else, do not follow this step. Build an adapter that meets the contract in [`adapters/github-sync/README.md`](adapters/github-sync/README.md#the-adapter-contract), and ask the user before you start.

**4.1 Create a GitHub App.** In your GitHub organization, create a GitHub App with the **Members** organization permission set to **Read and write**. Install it on the organization. Generate a private key. Note the **Client ID** and the **installation ID**, which is the number at the end of the installation URL.

**4.2 Create the teams.** For each repository, create a team named `owners-<repo>`, and make `CODEOWNERS` point at it, for example:

```
* @your-org/owners-payments-api
```

**4.3 Copy the adapter into your repository.** Copy `adapters/github-sync/.github/` and `adapters/github-sync/scripts/` into the root of a repository you own, and commit them to its default branch. GitHub only lists a `workflow_dispatch` workflow after it is on the default branch.

**4.4 Set the secrets and variables.** In that repository, under Settings, add:

| Kind | Name | Value |
|---|---|---|
| Secret | `PORT_CLIENT_ID` | Port client ID |
| Secret | `PORT_CLIENT_SECRET` | Port client secret |
| Secret | `OWNERSHIP_APP_PRIVATE_KEY` | The App's private key, the full PEM text |
| Variable | `OWNERSHIP_APP_CLIENT_ID` | The App's Client ID |
| Variable | `OWNERSHIP_INSTALLATION_ID` | The installation ID |
| Variable | `OWNERSHIP_GITHUB_ORG` | Your GitHub organization |
| Variable | `PORT_API_URL` | Port API including `/v1`, for example `https://api.port.io/v1` |
| Variable | `SERVICE_BLUEPRINT` | Optional. Defaults to `service` |

**4.5 Run a dry run.** Open **Actions > Sync owners team > Run workflow**. Fill in:

| Input | Example |
|---|---|
| `service` | `payments_api`, the Port service identifier |
| `repo` | `payments-api`, so the team synced is `owners-payments-api` |
| `mode` | `dry-run` |

**Expected:** the job summary lists the members to add, remove, and leave alone. It makes no changes to GitHub. Show this to the user.

**4.6 Apply.** Only after the user has reviewed the dry run and told you to, run the same workflow with `mode = apply`.

**Expected:** the members of `owners-<repo>` match the Port users who own the service and have a `github_login`.

> **Warning:** the first apply can remove people. GitHub adds the creator of a team to it. If you created `owners-<repo>` by hand, your own account is in it, and the sync removes it because it is not an owner in Port. Check the dry run first.

## Verify

Run these in the sandbox organization. A person runs the forms in Port. An agent can check the results through the Port MCP server or the API.

| Check | How | Expected |
|---|---|---|
| Create a swarm | Run **Create swarm** with name `Demo`, period `2026Q4`, and an existing team as parent | A `_team` entity appears with `team_kind = swarm` and `parent_team` set |
| Add a user | Run **Add user to swarm** for a user with a `github_login` | The user's `team` list gains `Demo`, and their existing teams are still there. `pending_swarm` is empty |
| Link to a service | Run **Add swarm to service** for a service | The service's owners gain the swarm **and** its parent team, existing owners are still there, and `pending_swarm` is empty |
| Audit | Open the **Ownership trail** page | A row for the service change and a row for the membership change |
| GitHub dry run | Run the sync with `mode = dry-run` | The diff matches the Port owners |
| GitHub apply | Run the sync with `mode = apply` | The members of `owners-<repo>` match Port |

If an existing owner or team disappears after a form runs, stop. Do not run the GitHub sync in apply mode. Compare the entity with its audit record on the Ownership trail, and report it.

## Clean up

Work through these in order, and check each one before you go on.

1. **GitHub.** Remove the workflow and scripts from your repository. Review the members of `owners-<repo>`, because the sync does not put back people it removed. Uninstall the GitHub App if nothing else uses it.
2. **Port, Terraform.** Run `terraform plan -destroy` first and read it. The module extends the built-in `_team` and `_user` blueprints rather than creating them, so check that the plan does not remove their own properties before you run `terraform destroy`.
3. **Port, CLI.** The CLI folder has no remove command. Delete the seven workflows, the four pages, and the `ownership_change` blueprint in the Port UI, or through the API. Deleting `ownership_change` deletes its audit records.
4. **Port data.** Swarm `_team` entities and their `pending_swarm` values stay in the catalog. Delete them in Port if you do not need them.
