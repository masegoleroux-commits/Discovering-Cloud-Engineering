# 0003 CloudTrail instead of GuardDuty and Security Hub

Status: Accepted (27 October 2026)

## Context
The first design used Amazon GuardDuty findings, tested with AWS sample findings, and AWS Security Hub. Deploying it failed:

- `guardduty:ListDetectors ... with an explicit deny in a service control policy`
- `securityhub:DescribeHub ... with an explicit deny in a service control policy`

An SCP deny comes from the organisation that owns the account and can't be overridden from inside it. The AWS free plan also only offers Always Free benefits, so the GuardDuty and Security Hub 30-day trials wouldn't have applied either.

## Decision
Detect risky actions directly from CloudTrail: a trail in eu-north-1 sends API-call events to EventBridge, and three rules pick out a security group opened to the internet, the trail being stopped or deleted, and a bucket's Block Public Access being removed. The formatter and responder Lambdas, the SNS alerts and the tag-only response stay the same.

## Alternatives rejected
- **Keep the GuardDuty design with synthetic findings** sent to a custom event bus: possible if labelled, but nothing would really be detected.
- **Record the project as blocked:** honest, but there was a working design within my account's limits.

## Consequences
- Detection is rule-based: it catches the actions I chose, not unusual behaviour the way GuardDuty's machine learning does. That's a real limitation, stated here.
- IAM and console sign-in events are recorded in us-east-1, which my account can't use, so a new access key or a sign-in without MFA isn't detected.
- The project needs its own trail. The first copy of management events is free.
- The deliberate test produces a real CloudTrail event on a harmless security group, so nothing is faked.
