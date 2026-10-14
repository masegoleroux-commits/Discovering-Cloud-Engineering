# 0005 ECS instead of EKS

Status: Accepted

## Context
Both ECS and EKS (Kubernetes) can run containers on AWS.

## Decision
Use ECS.

## Alternatives rejected
- **EKS:** the control plane is charged per hour, and Kubernetes adds a lot to learn and run for a single service.

## Consequences
Simpler to operate and explain. Kubernetes skills are still valuable; a later project can cover them on a local cluster such as kind.
