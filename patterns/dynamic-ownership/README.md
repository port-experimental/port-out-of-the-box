# Dynamic ownership

Let teams form, change, and dissolve without anyone editing team membership or ownership files by hand.

Ownership in most organizations is static. A service has an owning team, a file such as `CODEOWNERS` names the group that can review it, and both go stale the moment people move. This pattern makes **Port the single place where ownership changes**. A temporary team (a *swarm*) is linked to a service in Port. Access in downstream systems then follows automatically, and every change leaves an audit record.

![How ownership changes dynamically](docs/how-ownership-changes.png)

The pattern is generic. It works with whatever system a customer uses to manage teams and users. The included example syncs membership to GitHub teams, so `CODEOWNERS` never changes. A customer who manages teams in ServiceNow or Okta needs a different adapter for the same design.

## How it works

1. **Create a swarm** in Port with a form: name, period (for example `2026Q4`) and parent team.
2. **Add users** to the swarm with a form. The user's existing teams are kept.
3. **Link the swarm to a service** with a form. The swarm and its parent team are appended to the service's owners. Existing owners stay.
4. **The adapter** reads the service's owning teams from Port and makes the matching group in the downstream system contain exactly those people. The example adapter does this for a GitHub team.
5. **Every change is recorded** as an `ownership_change` entity, shown on an Ownership trail dashboard.

Port workflows can replace a list but cannot append to one, so each change is a form that stages a value, followed by an event workflow that appends it. [docs/design.md](docs/design.md) explains this in detail.

## Requirements

- A Port organization, client credentials, and admin rights to change blueprints.
- A **service blueprint** with **Direct ownership**, which gives it the `team` field. The pattern is written against a blueprint called `service`, but any name works. Inherited ownership does not work, because the workflows write the `team` list directly.
- Port **users and teams** in the catalog. Users normally arrive through SSO. Each person who should get downstream access needs the identifier the adapter uses. The example adapter reads `github_login` on the `_user` entity.
- For the example adapter: a GitHub organization, a GitHub App with Members read and write permission, and one team per repository named `owners-<repo>`. The adapter never creates teams.
- A way to apply the Port definitions: the Port CLI or Terraform. Neither depends on the other, and the Port CLI can create everything on its own. Use one, not both.

The [guide](GUIDE.md) turns these requirements into a checklist to confirm before you start.

## Constraints

These rules are built into the design. Keep them when you change the pattern.

- **A swarm has exactly one parent domain team.** The parent co-owns every service the swarm owns, so a domain team never loses visibility of a service its swarm owns. The adapter fails if a swarm owns a service without its parent as an owner.
- **Changes append, never overwrite.** Existing owners and existing teams are kept.
- **The adapter changes membership only.** It never creates or deletes downstream groups, and it never edits `CODEOWNERS`. It refuses to run if Port resolves no members, so it cannot empty a group by accident.

## Shortcomings

- **No removal flows.** The workflows add swarms to users and services. Removing a user from a swarm, retiring a swarm, or taking a swarm off a service is done by editing the entity in Port. The audit workflows record those edits, and the next sync updates the downstream system.
- **The adapter is not scheduled.** It runs on demand. Triggering it from Port when owners change, or on a schedule, is not included.
- **No approval step.** Anyone who can run the forms can change ownership. Port workflows support approval nodes, so one can be added in front of `add_swarm_to_service`.
- **The example adapter reads all users and teams in one call each.** Very large catalogs need pagination added to the script.
- **Dashboards are optional.** They are created through the API, so test them in a sandbox organization first.
- **Not yet verified end to end:**
  - The Terraform append template in the `teams` mapping has not been applied to a live organization. See [`port-config/terraform/README.md`](port-config/terraform/README.md).
  - The Port CLI script has only been run in dry-run mode against a test organization.
  - The audit workflows have not been seen firing in a live organization.
  - The example adapter has not been re-run against GitHub since its script was parameterized.
  - The pattern adds `user` to the allowed `entity_type` values of `ownership_change`. The test organization only allowed `service` and `team`.

## Where to go next

- [`GUIDE.md`](GUIDE.md): how to set the pattern up, including a prompt for a coding agent.
- [`docs/design.md`](docs/design.md): the data model, workflows, and dashboards.
- [`port-config/`](port-config): the Port definitions as JSON in [`definitions/`](port-config/definitions), applied with the [Port CLI](port-config/port-cli) or [Terraform](port-config/terraform).
- [`adapters/github-sync/`](adapters/github-sync): the example adapter for GitHub.
