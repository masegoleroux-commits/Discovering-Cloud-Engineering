# 0002 The pipeline owns the running version

Status: Accepted

## Context
Both Terraform and GitHub Actions can change the ECS service's task definition. If both do, Terraform would roll back each release on its next `apply`.

## Decision
Terraform sets the first task definition, then ignores changes to it (`lifecycle { ignore_changes = [task_definition] }`). The pipeline owns all later releases.

## Alternatives rejected
- **Terraform deploys every release:** mixes infrastructure changes with code releases and needs the image tag passed to Terraform on every push.

## Consequences
Clean split of responsibility. The task definition in Terraform state becomes outdated after the first release, which is expected.
