# Dynamic ownership: GitHub sync

A GitHub Action that keeps the GitHub team `owners-<repo>` in step with service ownership in Port. This is what turns an ownership change in Port into GitHub access.

For each service it:

1. Reads the service's owning teams from Port.
2. Fails if a swarm owns the service without its parent team as an owner.
3. Finds every Port user in any of those teams who has a `github_login`.
4. Makes the members of `owners-<repo>` exactly that set of people.

Only team **membership** changes. The script never creates or deletes teams, never edits `CODEOWNERS`, and refuses to run if Port resolves no members, so it can never empty a team by accident. Port users who own the service but have no `github_login` are listed in the job summary as skipped.

## What is in here

| Path | Contents |
|---|---|
| `.github/workflows/sync-owners.yml` | The workflow, started by hand from the Actions tab |
| `scripts/sync-owners.mjs` | The sync. Needs Node 20 and no packages |

The workflow is a thin wrapper around the script. To run it from another CI system, set the same environment variables and run `node scripts/sync-owners.mjs`.

## Set it up

This folder follows the layout used elsewhere in this repository: copy it into a repository you own so that `.github/` sits at the root of that repository and `scripts/` next to it. See the [repository README](../../../README.md#use-a-project-in-your-own-repo).

### 1. Create a GitHub App

Create a GitHub App owned by your organization, with the **Members** organization permission set to **Read and write**, and install it on the organization. Generate a private key. Note the **Client ID** and the **installation ID** (the number at the end of the installation URL).

### 2. Create the teams

For each repository, create a team named `owners-<repo>` and make `CODEOWNERS` point at it, for example `* @your-org/owners-payments-api`. You do this once. The sync never creates teams.

### 3. Set secrets and variables

On the repository that holds the workflow:

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

### 4. Run it

GitHub only lists a `workflow_dispatch` workflow once the file is on the repository's default branch. Then open **Actions > Sync owners team > Run workflow** and fill in:

| Input | Example |
|---|---|
| `service` | `payments_api`, the Port service identifier |
| `repo` | `payments-api`, so the team synced is `owners-payments-api` |
| `mode` | `dry-run` first, then `apply` |

The job summary shows a table of who would be added, removed or left alone.

## Behaviors to know

- **The first apply can remove people.** GitHub adds the creator of a team to it. If you created `owners-<repo>` by hand, your own account is in it, and the sync removes it because it is not an owner in Port. Check the dry run.
- **One run, one repository.** Run it once per service and repository pair.
- **Not scheduled.** There is no trigger from Port and no cron. To sync on a schedule, add an `on: schedule` trigger and loop over your services.
