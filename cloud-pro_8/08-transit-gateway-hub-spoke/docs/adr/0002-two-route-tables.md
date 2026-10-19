# 0002 Segmentation with two TGW route tables

Status: Accepted

## Context
Apps and data must reach shared services, but app ↔ data must be blocked.

## Decision
Disable the TGW default route table. Associate shared with `shared-rt` and app/data with `spokes-rt`. `spokes-rt` only receives the shared VPC's propagated route.

## Alternatives rejected
- **Security groups only:** they'd block it too, but routing would still allow the packets through the hub, and one wrong SG rule would open the path.
- **Network ACLs:** stateless and per-subnet; easy to get wrong in both directions.

## Consequences
Blocking happens at the hub, so a mistake in one spoke's security group can't open a path. Opening app ↔ data is one variable (`allow_app_to_data`), reviewed like any other code change.
