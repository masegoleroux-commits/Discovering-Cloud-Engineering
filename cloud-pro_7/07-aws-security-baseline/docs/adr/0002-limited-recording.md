# 0002 Record only 4 resource types

Status: Accepted

## Context
The Config recorder can record every supported resource type, or a chosen list.

## Decision
Record S3 buckets, security groups, EBS volumes and EC2 instances: the types the rules need.

## Alternatives rejected
- **Record everything:** in a real account Config charges per configuration item, and most of those items would never be evaluated.

## Consequences
Lower cost and less noise. New rules may need new resource types added to `config_resource_types`.
