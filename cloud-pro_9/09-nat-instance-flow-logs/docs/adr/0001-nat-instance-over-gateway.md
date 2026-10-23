# 0001 NAT instance instead of NAT gateway

Status: Accepted

## Context
The private subnet needs outbound internet access.

## Decision
Run NAT on a t4g.micro Amazon Linux 2023 instance with iptables, behind an Elastic IP.

## Alternatives rejected
- **Managed NAT gateway:** the production default: highly available within an AZ and scales to 100 Gbps, but about $32/month plus data charges, even idle.
- **No outbound access, VPC endpoints only:** great for AWS APIs (see Project 10), but can't reach the wider internet for updates.

## Consequences
Roughly 70% cheaper (about $6/month for the instance plus $3.65 for the Elastic IP, against about $32 plus data charges for a NAT gateway, at list prices) and very educational. I own the patching, the bandwidth limit (a micro instance has modest network performance) and failover. The recovery alarm handles host failure, but not an operating-system fault. For production I would use a NAT gateway per AZ.
