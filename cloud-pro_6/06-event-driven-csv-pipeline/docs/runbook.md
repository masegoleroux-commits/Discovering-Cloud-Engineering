# Runbook – 06 Event-Driven CSV Pipeline

The short operations card. For the full first-time walkthrough with every screenshot, see [START-HERE.md](START-HERE.md).

## Before you start

```bash
aws sts get-caller-identity      # Arn must end in :user/<your-admin-user>, never :root
cp -n infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars   # then fill it in
```

## Deploy and verify

```bash
pip install -r requirements-dev.txt && pytest -v      # 13 passed
./scripts/deploy.sh                                   # then confirm the SNS email
./scripts/upload_samples.sh && sleep 30
./scripts/check_results.sh                            # 1 SUCCEEDED, 1 FAILED, 3 rows, 1 DLQ message
```

## Tear down (same day)

```bash
./scripts/destroy.sh
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=csv-pipeline \
  --query 'ResourceTagMappingList[].ResourceARN' --output table      # should be empty
```

## Common problems

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Upload does nothing | File outside `incoming/`, or EventBridge off on the bucket | Check the key and `aws_s3_bucket_notification` |
| Rule matches but no execution | EventBridge role can't start the state machine | EventBridge → the rule → Monitoring → `FailedInvocations` |
| `Float types are not supported` | Amount passed as a float | `to_item` must use `Decimal` |
| `ExpiredToken` / `InvalidClientTokenId` | Access key deactivated or mistyped | Create a new key for your admin user and run `aws configure` |
| `No value for required variable` | `terraform.tfvars` missing or incomplete | Copy the example file and fill it in |
