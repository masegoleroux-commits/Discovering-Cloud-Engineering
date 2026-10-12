# 0002 DynamoDB instead of RDS

Status: Accepted

## Context
Notes are read and written by a single key (`note_id`). There are no joins or reports.

## Decision
Store notes in DynamoDB.

## Alternatives rejected
- **RDS (PostgreSQL/MySQL):** needs a VPC, a running instance, connection management from Lambda, and costs money while idle.

## Consequences
No server to run and no connection pooling. The sandbox fixes the table at 1 read and 1 write capacity unit, so this design handles a demo, not real traffic. In a real account I'd use on-demand billing.
