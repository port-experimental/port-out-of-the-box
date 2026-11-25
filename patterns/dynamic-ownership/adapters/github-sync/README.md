# Dynamic ownership: GitHub adapter

A sample adapter for the [dynamic ownership pattern](../../README.md). It keeps the GitHub team `owners-<repo>` in step with service ownership in Port, which is what turns an ownership change in Port into GitHub access.

The adapter is customer-specific. It is one implementation of the adapter contract below, built for customers who manage teams and users in Git. A customer who manages teams in ServiceNow or Okta needs a different implementation of the same contract.

## The adapter contract

Any adapter does the following. The GitHub adapter is one way to do it.

1. **Input:** a service identifier and the name of a downstream group, here `owners-<repo>`.
2. **Read the desired members from Port:** the service's owning teams, then every user in those teams who has the identifier the downstream system uses. Users who own the service but have no identifier are reported, not guessed.
3. **Refuse to run** if the service has no owners, a swarm owns the service without its parent team, or no members resolve.
4. **Change membership only.** Never create or delete the group, and never edit ownership files.
5. **Report the diff** before it changes anything, with a dry-run mode.

## What is in here

| Path | Contents |
|---|---|
| `.github/workflows/sync-owners.yml` | The workflow, started by hand from the Actions tab. It must sit at the root of the repository that runs it. |
| `scripts/sync-owners.mjs` | The sync. Needs Node 20 and no packages. |

The workflow is a thin wrapper around the script. To run the script from another CI system, set the same environment variables and run `node scripts/sync-owners.mjs`.

Setup steps, including the GitHub App and the secrets, are in the [guide](../../GUIDE.md#4-set-up-the-github-adapter).

## Behaviors to know

- **The first apply can remove people.** GitHub adds the creator of a team to it. If you created `owners-<repo>` by hand, your own account is in it, and the sync removes it because it is not an owner in Port. Check the dry run.
- **One run, one repository.** Run it once per service and repository pair.
- **Not scheduled.** There is no trigger from Port and no cron. To sync on a schedule, add an `on: schedule` trigger and loop over your services.
- **Port users without an identifier are skipped.** The job summary lists them, so you can add the identifier in Port.

## Replacing it

To use another system, keep the contract and replace the GitHub half of the script. Reading the desired members from Port does not depend on GitHub. Only the calls that read and change the downstream group are specific to GitHub.
