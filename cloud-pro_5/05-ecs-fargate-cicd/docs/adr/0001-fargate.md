# 0001 Fargate instead of ECS on EC2

Status: Accepted

## Context
ECS tasks can run on EC2 instances I manage, or on Fargate, where AWS manages the servers.

## Decision
Use Fargate.

## Alternatives rejected
- **ECS on EC2:** I would have to patch, scale and pay for the instances even when idle.

## Consequences
No servers to manage. Fargate costs more per vCPU-hour than a well-used EC2 instance, which only matters at steady, high utilisation. For one small service, the time saved on patching is worth more than the price difference.
