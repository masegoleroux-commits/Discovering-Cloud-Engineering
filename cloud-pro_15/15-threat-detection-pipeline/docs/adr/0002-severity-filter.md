# 0002 Filter by severity in EventBridge

Status: Accepted

## Context
Low-severity findings would flood the inbox.

## Decision
The EventBridge rule only matches findings at or above `min_severity` (default 4, Medium).

## Alternatives rejected
- **Filter inside the Lambda:** every finding still invokes it, and the rule is hidden in code.

## Consequences
The threshold is visible in the rule and in Terraform, and tested offline (TC-15-T03).
