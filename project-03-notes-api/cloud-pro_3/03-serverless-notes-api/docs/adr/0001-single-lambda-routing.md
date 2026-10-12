# 0001 One Lambda with internal routing

Status: Accepted

## Context
The API has four routes. Each could have its own Lambda, or one Lambda could handle all of them.

## Decision
Use one Lambda that branches on `routeKey`.

## Alternatives rejected
- **One Lambda per route:** four roles, four log groups and four deployments for very little code. Worth it only when routes need different permissions or scaling.

## Consequences
Simpler to deploy and reason about. The single role must allow all four actions, so if one route later needs extra permissions, split it out.
