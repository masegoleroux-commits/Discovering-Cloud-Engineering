# 0003 Flow Logs to CloudWatch Logs

Status: Accepted

## Context
Flow Logs can be delivered to CloudWatch Logs, S3 or Kinesis Data Firehose.

## Decision
Send them to CloudWatch Logs with 1-minute aggregation and 1-day retention, and save three Logs Insights queries.

## Alternatives rejected
- **S3 plus Athena:** cheaper for months of logs, but slower to query and more setup for a short demo.

## Consequences
Results appear within a couple of minutes and can be searched immediately. At high volume, S3 with Athena would be cheaper; I'd switch for long-term retention.
