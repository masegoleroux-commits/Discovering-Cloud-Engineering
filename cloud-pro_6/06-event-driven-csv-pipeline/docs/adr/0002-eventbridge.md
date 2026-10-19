# 0002 EventBridge instead of direct S3 notifications

Status: Accepted

## Context
S3 can trigger a Lambda directly, or send events to EventBridge.

## Decision
Send bucket events to EventBridge, with a rule filtered on the `incoming/` prefix that starts the state machine.

## Alternatives rejected
- **S3 → Lambda notification:** can't start Step Functions directly; I'd need an extra Lambda to start the workflow.

## Consequences
Prefix filtering in the rule, and easy to add more targets later (for example an audit log).
