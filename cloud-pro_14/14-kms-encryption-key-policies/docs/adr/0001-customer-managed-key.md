# 0001 A customer-managed key with a written key policy

Status: Accepted

## Context
Auditors ask who can decrypt data. AWS-managed keys don't let me control or show that.

## Decision
One customer-managed KMS key with automatic yearly rotation and a key policy written in Terraform.

## Alternatives rejected
- **AWS-managed keys (aws/s3 and so on):** free to use, but the key policy can't be changed or separated by role.
- **One key per service:** cleaner blast radius, but triples the monthly key cost for a demo.

## Consequences
About $1 a month per key (prorated). Every use of the key is in CloudTrail.
