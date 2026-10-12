# 0004 Scan with a limit for listing

Status: Accepted

## Context
`GET /notes` must return notes without a known key.

## Decision
Use `Scan` with `Limit=50`.

## Alternatives rejected
- **Query on a global secondary index:** better at scale but adds a second index to provision for a demo with a handful of items.

## Consequences
Fine for a few hundred items. A `Scan` reads the whole table, so with real data I'd add pagination (`LastEvaluatedKey`) and a GSI to query by owner or date.
