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

Each pattern lives in its own folder under `patterns/`. A pattern folder contains:

- A `README.md` that explains the problem, the design, what gets installed, and the limits of the pattern.
- One or more implementation folders, so a customer can choose how to install it. For example, `terraform/` for infrastructure as code and `port-cli/` for scripts that use the Port CLI.
- Any supporting code the pattern needs outside Port, such as a GitHub Action.

## Current patterns

- [`dynamic-ownership`](dynamic-ownership) — Let teams form and dissolve without editing GitHub teams or `CODEOWNERS` by hand. A temporary team (a swarm) is linked to a service in Port, GitHub team membership follows automatically, `CODEOWNERS` stays static, and every change is recorded.

## Adding a pattern

Before you add a folder here, check that it meets the definition above. Ask whether it combines several pillars, whether it solves a complex use case, and whether it fits more than one customer. If it only sets up a foundational concept, it belongs in the documentation or in a reference architecture instead.
