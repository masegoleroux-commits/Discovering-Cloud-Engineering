# 06 – Event-Driven CSV Processing Pipeline

Dropping a CSV of orders into an S3 folder starts a Step Functions workflow that validates the file, loads good rows into DynamoDB, and emails the result. A bad file is never silently lost: it goes to an SQS dead-letter queue with the reason, and I get a rejection email. All test data is synthetic.

![Architecture](docs/screenshots/00-architecture.svg)

## The problem

File-based integrations fail quietly: a partner sends a malformed file, half of it loads, and nobody notices until a report is wrong. This pipeline rejects bad files whole, explains why, and keeps a record of every failure.

## Tech stack

`Amazon S3` · `Amazon EventBridge` · `AWS Step Functions` · `AWS Lambda` · `DynamoDB` · `Amazon SQS` · `Amazon SNS` · `IAM` · `CloudWatch Logs` · `Terraform` · `Python 3.12` · `pytest` · `moto`

## Input file contract

| Column | Rule | Example |
|--------|------|---------|
| `order_id` | Required, unique within the file | `ORD-1001` |
| `customer_email` | Required, contains `@` | `test.user@example.com` |
| `amount` | Decimal greater than 0 | `249.99` |
| `currency` | `ZAR`, `USD`, `EUR` or `GBP` | `ZAR` |
| `order_date` | `YYYY-MM-DD` | `2026-10-15` |

Files must be UTF-8, at most 1 MB and 1,000 rows, so each load finishes well inside the 10-second Lambda timeout.

## Quickstart

```bash
cd cloud-pro_6/06-event-driven-csv-pipeline
pip install -r requirements-dev.txt && pytest -v
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars   # set owner and alert_email
./scripts/deploy.sh
./scripts/upload_samples.sh && sleep 30 && ./scripts/check_results.sh
./scripts/destroy.sh
```

Step-by-step guide: [docs/START-HERE.md](docs/START-HERE.md). Short operations card: [docs/runbook.md](docs/runbook.md).

## Key design decisions

- [0001 – Step Functions instead of chained Lambdas](docs/adr/0001-step-functions.md)
- [0002 – EventBridge instead of direct S3 notifications](docs/adr/0002-eventbridge.md)
- [0003 – Reject the whole file](docs/adr/0003-reject-whole-file.md)
- [0004 – Never retry validation errors](docs/adr/0004-no-retry-validation.md)

## Reliability, security and observability

- **Retries** only for temporary AWS errors (2 attempts with backoff); a `ValidationError` is never retried.
- **Idempotent loads:** re-uploading a file overwrites rows by `order_id` instead of duplicating them.
- **Separate IAM roles:** the validator can only read uploads; only the loader can write to the table.
- **Encryption:** S3 (SSE-S3) and SQS (SSE-SQS) at rest; the bucket blocks all public access.
- **Logs:** every state transition is logged (`level = ALL`), plus structured JSON from both Lambdas.

## Screenshots

| # | What it proves | File |
|---|----------------|------|
| 1 | Tests pass locally | ![](docs/screenshots/01-pytest-pass.png) |
| 2 | Infrastructure deployed from code | ![](docs/screenshots/02-terraform-apply.png) |
| 3 | The workflow definition | ![](docs/screenshots/03-state-machine-definition.png) |
| 4 | A good file loaded (green path) | ![](docs/screenshots/04-executionsuccess.png) |
| 5 | A bad file rejected (red path) | ![](docs/screenshots/05-executionrejected.png) |
| 6 | Rows in DynamoDB | ![](docs/screenshots/06dynamodb-items.png) |
| 7 | Rejection reason in the dead-letter queue | ![](docs/screenshots/07-deadletterqueue.png) |
| 8 | Success and rejection emails | ![](docs/screenshots/08-emails.png) |
| 9 | Re-upload doesn't duplicate rows | ![](docs/screenshots/09-idempotent-reload.png) |
| 10 | Everything torn down | ![](docs/screenshots/10-terraform-destroy.png) |

## Cost and teardown

Built and tested in my own AWS account. Every service here is billed per use (Lambda, Step Functions, on-demand DynamoDB, SQS, SNS, S3), so a build-and-test session costs **well under $0.01** and is usually covered by the AWS Free Tier. `./scripts/destroy.sh` removes everything; uploaded files also expire after 1 day.

_Estimates from AWS list prices, October 2026; prices in eu-north-1 (Stockholm), where this was built, are similar. Check your own bill in Billing → Cost Explorer._

## Lessons learned

<!-- Fill in after building. Only record what actually happened. -->
