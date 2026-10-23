# 0001 Gateway endpoints for S3 and DynamoDB

Status: Accepted

## Context
The workload needs S3 and DynamoDB with no internet access.

## Decision
Use gateway endpoints, attached to the private route table, each with a policy limited to the project's resources.

## Alternatives rejected
- **Interface endpoints for S3:** work too (and from on-premises), but cost per hour per AZ, while gateway endpoints are free.
- **NAT gateway:** sends AWS traffic via the internet path and charges per GB.

## Consequences
Zero cost and no DNS changes; the route table gets prefix-list routes. Gateway endpoints only work from inside the VPC they're attached to, not from peered VPCs or on-premises.
