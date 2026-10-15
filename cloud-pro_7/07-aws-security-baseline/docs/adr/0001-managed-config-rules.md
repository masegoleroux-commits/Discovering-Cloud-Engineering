# 0001 AWS managed Config rules

Status: Accepted

## Context
Config rules can be AWS managed or custom (backed by a Lambda function I write).

## Decision
Use 6 AWS managed rules.

## Alternatives rejected
- **Custom Lambda rules:** I'd have to maintain the code, and every evaluation is another paid Lambda call.

## Consequences
Maintained by AWS and well documented. Custom rules remain an option for organisation-specific policies.
