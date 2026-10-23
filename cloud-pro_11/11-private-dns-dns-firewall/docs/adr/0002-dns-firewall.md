# 0002 DNS Firewall instead of host-based blocking

Status: Accepted

## Context
Known-bad domains should be blocked for every server.

## Decision
Use Route 53 Resolver DNS Firewall, associated with the VPC.

## Alternatives rejected
- **Blocklists on each server:** must be installed, updated and trusted on every machine; one forgotten server is a gap.
- **A self-managed DNS proxy:** another server to run, patch and make highly available.

## Consequences
One rule group protects the whole VPC and can be shared to others with Firewall Manager. It only sees queries sent to the VPC resolver, so it should be paired with egress controls that stop servers using outside resolvers.
