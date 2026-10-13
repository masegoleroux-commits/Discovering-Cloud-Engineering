# 0004 Web server in a public subnet, no load balancer

Status: Accepted

## Context
A production web tier usually sits in private subnets behind an Application Load Balancer.

## Decision
Run one instance in a public subnet, with only port 80 open.

## Alternatives rejected
- **ALB plus private instances:** the right production pattern, but the private instances couldn't install packages without a NAT gateway (ADR 0003). Project 05 demonstrates the ALB pattern instead.

## Consequences
Simple and cheap, with no high availability: one instance in one AZ. I would move to an Auto Scaling group across both AZs behind an ALB for real traffic.
