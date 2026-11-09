# 0001 Tag, don't remove the rule

Status: Accepted (updated 27 October 2026 for the CloudTrail design)

## Context
An automated response to a false positive can cause an outage worse than the threat. A security group opened to the internet is sometimes intended, for example a public web server on port 443.

## Decision
The responder only adds a `SecurityFinding` tag to a security group that was opened to the internet. It never removes the rule. Trail and bucket events are emailed but never acted on automatically. People decide what happens next.

## Alternatives rejected
- **Revoke the rule automatically:** fast, but a false positive takes a real service offline.
- **No automation:** nothing marks what needs attention.

## Consequences
The responder's IAM policy only allows `ec2:CreateTags` on security groups with the tag key `SecurityFinding`, so removing a rule isn't even possible (TC-15-T04). Proved by TC-15-U09 to U13 and TC-15-L06: the rule is still there after the responder runs, and the test script removes it.
