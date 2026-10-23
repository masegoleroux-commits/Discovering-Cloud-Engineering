# 0003 Three layers of policy

Status: Accepted

## Context
A single control can fail or be misconfigured.

## Decision
Enforce data access at three independent layers: IAM (what the identity may do), the endpoint policy (what can pass through this network path), and the bucket policy (who may read this data, from where).

## Alternatives rejected
- **IAM only:** a stolen credential could still write to an attacker's bucket over any network path.

## Consequences
Each layer can block on its own, which the tests demonstrate. The cost is more policies to keep in sync; Terraform manages all three together so they can't drift apart.
