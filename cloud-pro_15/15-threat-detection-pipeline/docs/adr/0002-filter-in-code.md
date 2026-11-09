# 0002 Match the action in EventBridge, decide "open to the internet" in code

Status: Accepted

## Context
CloudTrail records a security-group rule as a list of permissions, each with its own list of address ranges. I want an alert only when one of them is `0.0.0.0/0` or `::/0`. EventBridge patterns can filter on fields, but AWS's documentation on matching inside lists of objects is thin, and the pattern can't be tested offline without AWS.

## Decision
The `sg-open-to-internet` rule matches the action, `AuthorizeSecurityGroupIngress`. The formatter and the responder then check every permission for an internet-wide range, and do nothing for private rules. The trail and bucket rules filter fully in EventBridge, because their action names alone are risky.

## Alternatives rejected
- **Filter the address range in the EventBridge pattern:** fewer Lambda runs, but I couldn't prove the pattern works without deploying, and a pattern that silently never matches would hide real alerts.
- **One rule for everything:** harder to read, and the three detections have different severities.

## Consequences
Every new inbound rule in the region invokes the two functions once. That's free at this scale, and private rules send no email (TC-15-U08, U12). The internet-wide check, including IPv6, port ranges and "all traffic", is covered by unit tests TC-15-U01, U02, U08 and U10.
