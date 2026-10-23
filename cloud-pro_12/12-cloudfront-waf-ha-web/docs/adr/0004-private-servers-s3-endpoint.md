# 0004 Private web servers with an S3 gateway endpoint

Status: Accepted

## Context
Web servers should have no public IPs and no internet route, but they need to install Nginx at boot.

## Decision
Place them in private subnets with no NAT, and add a free S3 gateway endpoint. Amazon Linux 2023's package repositories are hosted in S3, so `dnf install` works through it.

## Alternatives rejected
- **NAT gateway:** about $32/month, and gives the servers general internet access they don't need.
- **Public subnets:** each server would need a public IP and could be reached if a security group rule were wrong.

## Consequences
No internet path at all, at no cost. If the boot script ever needed something outside S3, it would fail; the fix would be a golden AMI with everything pre-installed.
