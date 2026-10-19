# 0003 Reachability Analyzer instead of test instances

Status: Accepted

## Context
Connectivity has to be proved, both reachable and blocked.

## Decision
Put one free network interface (ENI) in each VPC and test paths between them with VPC Reachability Analyzer.

## Alternatives rejected
- **EC2 test instances and ping/curl:** needs instances, SSM access (internet or endpoints) and more cost, and a failed ping doesn't say *why*.

## Consequences
Each analysis costs about $0.10 and explains exactly which component allows or drops the traffic. It analyses configuration, not live packets, so it can't catch problems inside an operating system.
