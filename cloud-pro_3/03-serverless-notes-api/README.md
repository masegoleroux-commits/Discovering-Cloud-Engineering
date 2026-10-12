# 03 – Serverless Notes API

A REST API that creates, reads, lists and deletes notes, built from API Gateway, one Python Lambda and a DynamoDB table, all deployed with Terraform.

![Architecture](docs/screenshots/00-architecture.png)

## The problem

Small internal tools often need a simple data API without a server to patch or pay for when idle. This project shows how to build one with least-privilege access and tests that cost nothing to run.

## Tech stack

`AWS Lambda` · `API Gateway (HTTP API)` · `DynamoDB` · `IAM` · `CloudWatch Logs` · `Terraform` · `Python 3.12` · `pytest` · `moto` · `GitHub Actions`

## Quickstart

```bash
cd cloud-pro_3/03-serverless-notes-api
python -m venv .venv && source .venv/bin/activate      # Windows Git Bash: source .venv/Scripts/activate
pip install -r requirements-dev.txt
pytest -v                                               # all tests run locally, no AWS needed

cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars   # set owner
./scripts/deploy.sh
./scripts/smoke_test.sh
./scripts/destroy.sh
```

New here? Follow [docs/START-HERE.md](docs/START-HERE.md) from an empty computer to a finished project. The shorter checklist is [docs/runbook.md](docs/runbook.md).

## API

| Method | Path | Success | Errors |
|--------|------|---------|--------|
| `POST` | `/notes` | 201 + note | 400 if title missing, too long, or body isn't JSON |
| `GET` | `/notes` | 200 + up to 50 notes | |
| `GET` | `/notes/{note_id}` | 200 + note | 404 if not found |
| `DELETE` | `/notes/{note_id}` | 204 | |

## Key design decisions

- [0001 – One Lambda with internal routing](docs/adr/0001-single-lambda-routing.md)
- [0002 – DynamoDB instead of RDS](docs/adr/0002-dynamodb-over-rds.md)
- [0003 – HTTP API instead of REST API](docs/adr/0003-http-api.md)
- [0004 – Scan with a limit for listing](docs/adr/0004-scan-for-listing.md)

## Security and observability

- The Lambda role allows **4 DynamoDB actions on 1 table** and writing to **its own log group only**.
- API Gateway throttles to 1 request per second (burst 5), which protects the sandbox's 300-invocations-per-hour Lambda limit.
- DynamoDB encryption at rest is on. Errors return a `request_id` to the caller; the details stay in CloudWatch Logs.
- Logs are structured JSON, so they can be searched with CloudWatch Logs Insights.

## Screenshots

| # | What it proves | File |
|---|----------------|------|
| 1 | Unit tests pass locally | ![](docs/screenshots/01-pytest-pass.png) |
| 2 | Infrastructure deployed from code | ![](docs/screenshots/02-terraform-apply.png) |
| 3 | Four routes in API Gateway | ![](docs/screenshots/03-api-gateway-routes.png) |
| 4 | Lambda limits inside the sandbox caps | ![](docs/screenshots/04-lambda-config.png) |
| 5 | IAM policy scoped to one table | ![](docs/screenshots/05-iam-policy.png) |
| 6 | Working API calls, including a rejected bad request | ![](docs/screenshots/06-smoke-test.png) |
| 7 | Data stored in DynamoDB | ![](docs/screenshots/07-dynamodb-items.png) |
| 8 | Structured JSON logs | ![](docs/screenshots/08-cloudwatch-logs.png) |
| 9 | CI pipeline passing | ![](docs/screenshots/09-github-actions-ci.png) |
| 10 | Everything torn down | ![](docs/screenshots/10-terraform-destroy.png) |

## Cost and teardown

Runs inside the KodeKloud sandbox at no cost to me. In a personal account this would sit within the AWS Free Tier at this traffic level. `./scripts/destroy.sh` removes every resource.

## Lessons learned

<!-- Fill this in after you build it: what broke, what you'd change, what surprised you. Only write what actually happened. -->
