# 0001 Private hosted zone for internal names

Status: Accepted

## Context
Internal services need stable names that the internet can't see.

## Decision
Use a Route 53 private hosted zone, `corp.internal`, associated with the VPC.

## Alternatives rejected
- **/etc/hosts files on each server:** drift immediately and don't scale.
- **A public zone with private IPs:** works, but reveals the internal network layout to anyone who looks.

## Consequences
Names resolve only inside associated VPCs. `.internal` is reserved for private use, so it can never clash with a real public domain. Sharing with more VPCs is one association each.
