# 0001 Custom rotation for an API key

Status: Accepted

## Context
I needed a rotation I could watch step by step and test without paying for a database.

## Decision
Rotate a partner API key with my own Lambda implementing Secrets Manager's four steps, against a DynamoDB key registry that stands in for the partner.

## Alternatives rejected
- **Managed rotation for an RDS password:** needs a running database (cost) and hides the steps I wanted to learn.
- **A scheduled script outside Secrets Manager:** loses version labels, built-in retries and the audit trail.

## Consequences
Every step is visible in logs and covered by 13 unit test cases. The registry is a stand-in: a real partner would expose an API to register keys.
