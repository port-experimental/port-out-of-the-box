# Patterns

A **pattern** is a complex use case that Port makes simple to manage. It is built from more than one of Port's pillars, and it can be implemented for many customers, with each one adapting it to their own organization.

## What counts as a pattern

A pattern has all of these properties:

- **It combines more than one pillar.** A pattern uses several of Port's building blocks together, for example blueprints, relations, workflows, pages, and integrations, so that the whole works as one capability.
- **It solves a complex problem.** The use case is hard to build from scratch. Port turns it into something a team can install, run, and maintain.
- **It applies to multiple customers.** The same design fits many organizations. Customers change names, teams, and details, but not the shape of the solution.

## What is not a pattern

Some things are needed in almost every Port setup, whatever the use case. These are **foundational concepts**, not patterns:

- **Blueprints**, the data model that everything else depends on.
- **Workflows**, the way Port runs automated and self-service processes.
- **Promotion pipelines**, the way configuration moves between environments, such as Integration, Staging, and Production.

Each of these is a building block. A pattern uses them, but a pattern is not one of them. For example, a workflow that creates a Jira ticket is a foundational workflow. A system that uses blueprints, workflows, pages, and an external integration to keep access in sync with ownership is a pattern.

A quick test: if the concept is needed no matter what the use case is, it is foundational. If it only makes sense as part of a particular complex problem that uses several pillars together, it is a pattern.

## How patterns are organized

Each pattern lives in its own folder under `patterns/`, laid out like this:

```
patterns/<pattern-name>/
├── README.md        what the pattern is and how to get started with it
├── GUIDE.md         step-by-step guide, with a prompt for a coding agent
├── docs/            all the relevant documentation for the pattern
├── adapters/        customer-specific: parts outside Port that vary by customer
└── port-config/     port-specific: what you create in Port
    ├── terraform/   customers choose one of these two
    └── port-cli/
```

- **`README.md`** explains what the pattern is and how to get started using it.
- **`GUIDE.md`** walks someone through setting the pattern up, step by step. See [The guide](#the-guide).
- **`docs/`** holds the rest of the documentation: design, data model, diagrams, and limits.
- **`adapters/`** (customer-specific) holds the artifacts that connect the pattern to systems outside Port. These depend on the customer's ecosystem. Think of it as an interface with sample implementations. For example, the dynamic ownership pattern's `github-sync/` is one implementation for customers who manage teams and users in Git. A customer who manages teams in ServiceNow or Okta needs a different implementation of the same design.
- **`port-config/`** (port-specific) holds what a customer creates in Port: blueprints, workflows, and pages. Customers choose either `terraform/` or `port-cli/`. Both produce the same result.

### The guide

Every pattern has a `GUIDE.md`, in the style of the [Port guides](https://docs.port.io/guides/all/ai-powered-incident-management/). Someone trying the pattern should be able to hand it to a coding agent and have the agent set the pattern up from the prompt in the guide and the files in the pattern folder. Write it so that a person and an agent can both follow it.

A guide has these parts, in this order:

1. **Implement with AI.** A prompt to copy into a coding agent. It tells the agent to read the pattern's `README.md`, `GUIDE.md`, and files; to ask for the inputs it needs instead of guessing; to work in a sandbox organization and run a dry run first; to ask before it changes anything; and to verify the result at the end. It also lists what the agent needs, for example the Port MCP server if the agent should inspect your organization.
2. **Overview.** What the pattern does, and common use cases.
3. **Prerequisites.** Everything that must be true before starting, in three groups:
   - **Port:** an account, the role needed, credentials, and any blueprints that must already exist. For example, dynamic ownership needs a service blueprint with Direct ownership.
   - **Customer systems:** the outside systems the adapter talks to, and what must be set up in them. For example, a GitHub organization, a GitHub App, and one `owners-<repo>` team per repository.
   - **Tools:** what must be installed, such as Terraform or the Port CLI, `jq`, and Node.
4. **Inputs.** The values the person must provide, with defaults, such as the service blueprint identifier or the GitHub organization. An agent asks for these.
5. **Steps.** Numbered. Each step names the file or folder it uses, the command to run, and the result to expect. Port steps offer `terraform/` or `port-cli/`. The adapter step offers the sample implementation and says what to build if the customer's ecosystem is different.
6. **Verify.** Checks with expected results, so a person or an agent can confirm the pattern works.
7. **Clean up.** How to remove what the guide created.

To keep a guide safe for an agent to follow:

- Start in a sandbox organization, and run a dry run before any apply. Steps should be safe to repeat.
- Never put secrets in the prompt or in files. Pass credentials as environment variables.
- Say what the agent must not do without asking, such as applying to a production organization or changing an existing blueprint beyond adding to it.
- Refer to files by relative path, so the agent finds them in the pattern folder.

## Current patterns

- [`dynamic-ownership`](dynamic-ownership) — Let teams form and dissolve without editing GitHub teams or `CODEOWNERS` by hand. A temporary team (a swarm) is linked to a service in Port, GitHub team membership follows automatically, `CODEOWNERS` stays static, and every change is recorded.

## Adding a pattern

Before you add a folder here, check that it meets the definition above. Ask whether it combines several pillars, whether it solves a complex use case, and whether it fits more than one customer. If it only sets up a foundational concept, it belongs in the documentation or in a reference architecture instead.
