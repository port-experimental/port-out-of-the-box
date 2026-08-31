# Port out of the box

Get to value with [Port](https://www.port.io/) faster. This repo exists to ease onboarding and shorten time-to-value by providing high-level, composable patterns alongside working, out-of-the-box resources. Combine Port's flexibility with these ready-made building blocks to rapidly fit the needs of your organization.

Everything here is a working example, not a demo stub. Fork it and run a project as-is, or lift a project into your own repo and adapt it to your toolchain.

## Start here

Pick a [reference architecture](#reference-architectures) below, then choose a path:

- **[Try it in a fork](#try-a-project-in-this-repo)** — enable the project in this catalog and watch the pipeline run end to end.
- **[Adopt it in your own repo](#use-a-project-in-your-own-repo)** — copy the project folder into a repo you own and run it as your pipeline.

You will need a Port account with [client credentials](https://docs.port.io/build-your-software-catalog/custom-integration/api/#get-api-token), and admin access on your fork (or target repo) to create GitHub Environments.

## Reference architectures

- [`reference-architecture/port-resource-promotion/port-cli`](reference-architecture/port-resource-promotion/port-cli) — **start here if you are new.** Promote your Port configuration through Integration, Staging, and Production using a GitOps pipeline: review a diff on every pull request, deploy on merge, and roll out on release. Needs nothing beyond Port credentials.
- [`reference-architecture/port-resource-promotion/terraform`](reference-architecture/port-resource-promotion/terraform) — Promote Port configuration as Terraform through the same Integration → Staging → Production ladder: plan on pull request, apply on merge, and roll out on release. Also needs Terraform Cloud for state.
- [`reference-architecture/integration/azure-tf`](reference-architecture/integration/azure-tf) — Deploy Port's Azure integration on Azure Container Apps with Event Grid for real-time catalog updates across one or more subscriptions (Terraform). Also needs an Azure subscription and Terraform Cloud (or another state backend).

## Toolchain

Working examples have to pick concrete tools, so these projects use GitHub Actions for CI/CD, Terraform for infrastructure, and Terraform Cloud for Terraform state. Port itself is driven through the [Port CLI](https://docs.port.io/) and the [Port Terraform provider](https://registry.terraform.io/providers/port-labs/port-labs/latest/docs).

What matters here is the pattern, not the tools. The promotion ladder, the environment and credential boundaries, the review-before-apply gates, and the Port operations behind them all carry over to GitLab CI, Azure Pipelines, Jenkins, Pulumi, or a different state backend. If your stack differs, read a project as a specification you can port to it — the structure and reasoning are the durable part.

## How this repo is organized

Each reference architecture in this repo is a **project**: a self-contained folder under `reference-architecture/` with its own pipeline, composite actions, and configuration or Terraform — for example:

```
reference-architecture/port-resource-promotion/port-cli/
├── .github/
│   ├── workflows/          # the project's pipeline
│   └── actions/            # composite actions the pipeline calls
├── port-config-port-cli/   # the project's data
└── README.md               # how to run this project
```

GitHub Actions only runs workflows found in the **repository root** `.github/workflows/` directory. Workflows nested inside a project folder are inert: they ship as a package you enable deliberately, so forking this repo never fires a pipeline you did not ask for.

That gives you two ways to consume a project: [enable it in a fork of this repo](#try-a-project-in-this-repo), or [copy it into a repo of your own](#use-a-project-in-your-own-repo).

## Try a project in this repo

Use this when you want to see a project run end to end before committing to it.

1. **Fork this repo** and confirm Actions are allowed under **Settings → Actions → General**.
2. **Stop ignoring the root `.github/` directory.** In [`.gitignore`](.gitignore), comment out the `/.github/` line. It is ignored by default so that enabling a project is always an explicit choice.
3. **Copy the project's `.github/` directory to the repository root.** For the Port CLI promotion pipeline:

   ```bash
   cp -R reference-architecture/port-resource-promotion/port-cli/.github .github
   ```

   Copy real files — GitHub does not follow symlinks when it looks for workflows. To enable more projects later, copy their `.github/` contents into the same root tree; workflow and action names are project-scoped, so they merge rather than collide.
4. **Follow that project's README** for its GitHub Environments, secrets, variables, and any data it needs (a config export, tfvars, and so on).
5. **Commit and push.** Runners only see what is committed, so the root `.github/` directory must land in your fork before the pipeline can run.

Leave the project's data where it is — nested inside the project folder. Only `.github/` needs to move.

If you later edit a project's workflow or actions, copy them to the root again. The nested project folder is the source of truth; the root `.github/` directory is a copy that GitHub can see.

**What you should see:** the enabled workflow appears under the **Actions** tab. Open a pull request that touches the project's config and you get a review comment showing what would change; merge to `main` and the pipeline applies that change to Integration. That is the loop working.

## Use a project in your own repo

Use this when a project has earned a permanent place in your platform. Copy the project folder's contents into a repo of your own, so its `.github/` directory sits at that repo's root, then follow the project README. Because the pipelines here ship pointed at this repo's nested layout, check the project README for the paths to adjust once the project sits at your repository root.

## Contributing

Contributions are welcome, and the fork-and-enable flow above is also the contributor flow: work in your fork, run the pipelines for real, then open a pull request for the changes worth sharing.

Two conventions keep that clean:

- **Edit the nested project folder.** It is the package customers consume. A root `.github/` directory is only ever a local copy of it.
- **Keep the root `.github/` directory out of your pull requests**, along with the `.gitignore` change that allowed you to commit it. Those are artifacts of running the code, not part of the project.

Questions, problems, or requests? [Open an issue](https://github.com/port-experimental/port-out-of-the-box/issues) on this repository.
