# Runbook – 07 AWS Security Baseline

The short operations card. For the full first-time walkthrough with every screenshot, see [START-HERE.md](START-HERE.md).

## Before you start

```bash
aws sts get-caller-identity      # Arn must end in :user/<your-admin-user>, never :root
cp -n infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars   # then fill it in
```

## Deploy and verify

```bash
aws configservice describe-configuration-recorders    # if one exists: create_config_recorder = false
./scripts/deploy.sh                                   # then confirm the SNS email
./scripts/create_test_violations.sh                   # deliberate test
./scripts/compliance_report.sh                        # after 10-15 minutes
./scripts/cleanup_test_violations.sh
```

## Tear down (same day)

```bash
./scripts/destroy.sh
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=security-baseline \
  --query 'ResourceTagMappingList[].ResourceARN' --output table      # should be empty
```

## Common problems

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `MaxNumberOfConfigurationRecordersExceeded` | A recorder already exists | Set `create_config_recorder = false` |
| Rules stuck on "No results" | Recorder not running | Config → Settings; recording must be on |
| Metric filter never increases | Events take 5–15 min to reach CloudWatch Logs | Wait; use **Test pattern** on the metric filter |
| `ExpiredToken` / `InvalidClientTokenId` | Access key deactivated or mistyped | Create a new key for your admin user and run `aws configure` |
| `No value for required variable` | `terraform.tfvars` missing or incomplete | Copy the example file and fill it in |
