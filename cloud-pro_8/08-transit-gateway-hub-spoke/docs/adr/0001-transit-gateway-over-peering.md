# 0001 Transit Gateway instead of VPC peering

Status: Accepted

## Context
Three VPCs need controlled connectivity, and more VPCs will be added later.

## Decision
Connect every VPC to a single Transit Gateway.

## Alternatives rejected
- **VPC peering:** free per hour, but peering isn't transitive, so every pair needs its own connection (n×(n−1)/2), and segmentation logic is spread across every VPC's route tables.
- **Shared VPC / one big VPC:** simpler, but no network boundary between workloads.

## Consequences
One hub to inspect and change. Costs about $0.05 per attachment per hour plus data processing, which is the price of central control. For two VPCs that will never grow, peering would be the cheaper choice.
