# ADR 0004: VPC peering instead of Transit Gateway

**Status:** Accepted (supersedes ADR 0001 and ADR 0002 for this account)

## Context
`terraform apply` failed on `ec2:CreateTransitGateway` with an explicit deny in an
organization service control policy (`p-ije59ssj`). An SCP deny can't be overridden
from the member account, even by an administrator.

## Decision
Connect the VPCs with VPC peering: shared <-> app and shared <-> data. An app <-> data
peering is created only when `allow_app_to_data = true`.

## Consequences
- Peering is non-transitive, so app and data stay isolated from each other by default.
  This replaces the two TGW route tables from ADR 0002.
- No hourly cost. Only data transfer is billed.
- This doesn't scale like a TGW. A full mesh of n VPCs needs n(n-1)/2 peerings.
- The original design is kept in `infrastructure/tgw.tf.disabled`. To restore it,
  rename that file back to `tgw.tf` and revert `peering.tf`, `network.tf`, `outputs.tf`
  and the tests.
