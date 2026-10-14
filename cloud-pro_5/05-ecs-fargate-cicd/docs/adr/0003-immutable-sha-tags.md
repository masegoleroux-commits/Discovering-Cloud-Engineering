# 0003 Immutable tags from the commit SHA

Status: Accepted

## Context
Images need tags. `latest` is common but ambiguous.

## Decision
Tag every image with the short commit SHA and make tags immutable in ECR.

## Alternatives rejected
- **`latest`:** two different images can share the tag, so I can't tell what is running or roll back reliably.
- **Semantic versions:** good for libraries, but needs a manual step for each release.

## Consequences
Every running task traces back to a commit. Re-pushing a tag is rejected, so a re-run of the same commit needs the old image deleted first.
