# 0002 One Availability Zone

Status: Accepted

## Context
A highly available design would repeat the subnets and NAT in a second AZ.

## Decision
Use one AZ for both subnets.

## Alternatives rejected
- **Two AZs with a NAT each:** doubles the instances and Elastic IPs for no learning benefit here.
- **Two AZs sharing one NAT:** adds cross-AZ data charges and still has a single point of failure.

## Consequences
If that AZ fails, the project is down. The design note in the README explains the production version: one NAT per AZ, each private route table pointing to its own AZ's NAT.
