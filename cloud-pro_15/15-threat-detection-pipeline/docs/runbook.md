# Runbook – 15 Threat Detection Pipeline

Full walkthrough: [START-HERE.md](START-HERE.md). Test cases: [TEST-CASES.md](TEST-CASES.md).

```bash
aws sts get-caller-identity                       # admin user, not root
python -m pytest -v                               # unit test cases (free)
terraform -chdir=infrastructure test              # offline test cases (free)
./scripts/deploy.sh
./scripts/run_tests.sh                            # deliberate test, closes the port again
./scripts/destroy.sh                              # same day
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=threat-detect \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `TC-15-L04 no alert yet` | CloudTrail events can take several minutes to reach EventBridge, especially just after the trail is created | Wait 5 minutes and run `./scripts/run_tests.sh` again |
| `TC-15-L01 ... is not logging` | The trail was stopped | `aws cloudtrail start-logging --name threat-detect-dev-trail` |
| `TrailAlreadyExists` or a limit on trails | A trail with that name, or the maximum number of trails, already exists | If a trail is already logging in eu-north-1, set `create_trail = false` |
| An unexpected `CRITICAL: DeleteTrail` email during `destroy` | Terraform deleted this project's own trail, and that is exactly what the rule watches for | Expected; it shows the rule works |
| No email | Subscription not confirmed, or in junk | **SNS → Subscriptions** must say **Confirmed**; mark the sender as not junk |
| The test group still has port 22 open after a crash | The script was killed before its clean-up | `aws ec2 revoke-security-group-ingress --group-id <test group id> --protocol tcp --port 22 --cidr 0.0.0.0/0` |
