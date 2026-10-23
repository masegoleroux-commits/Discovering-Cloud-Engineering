# 0002 Interface endpoints in one AZ

Status: Accepted

## Context
Session Manager and Run Command need the `ssm`, `ssmmessages` and `ec2messages` endpoints, each charged per AZ.

## Decision
Create them in one subnet (one AZ) only, next to the workload.

## Alternatives rejected
- **One per AZ:** the production pattern for resilience, but it doubles the hourly cost for no benefit with a single instance.

## Consequences
If that AZ fails, management access is lost. In production I'd deploy them in every AZ that runs workloads, and share them across VPCs from a central networking VPC to save cost.
