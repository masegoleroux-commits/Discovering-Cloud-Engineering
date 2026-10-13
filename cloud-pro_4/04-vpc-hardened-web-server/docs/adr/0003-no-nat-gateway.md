# 0003 No NAT gateway

Status: Accepted

## Context
Private subnets normally reach the internet through a NAT gateway for updates.

## Decision
No NAT gateway. The private subnets have local routes only.

## Alternatives rejected
- **NAT gateway:** about $0.045 per hour (roughly $32 a month) plus a charge per GB, even when idle. Too expensive for a portfolio project.
- **NAT instance:** cheaper, but another server to patch.

## Consequences
Anything placed in the private subnets cannot download updates. In production I would use VPC endpoints for AWS services and a NAT gateway only where general internet access is needed.
