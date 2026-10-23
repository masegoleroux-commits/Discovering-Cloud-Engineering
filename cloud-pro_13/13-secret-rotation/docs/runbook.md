# Runbook – 13 Automatic Secret Rotation

Full walkthrough: [START-HERE.md](START-HERE.md). Test cases: [TEST-CASES.md](TEST-CASES.md).

```bash
aws sts get-caller-identity                       # admin user, not root
pytest -v                                         # unit test cases (free)
terraform -chdir=infrastructure test              # offline test cases (free)
./scripts/deploy.sh
./scripts/run_tests.sh
./scripts/destroy.sh                              # same day
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=secret-rotation \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `TC-13-L02 rotation 1 did not finish` | The rotation function failed a step | Open its log group; the error names the step. Fix, then `aws secretsmanager cancel-rotate-secret --secret-id secret-rotation-dev/partner-api-key` and re-run |
| `pytest` can't import `moto` | Dev requirements not installed | `pip install -r requirements-dev.txt` inside your `.venv` |
| `A secret with this name is already scheduled for deletion` on deploy | A previous run's secret is still in its recovery window | `aws secretsmanager delete-secret --secret-id secret-rotation-dev/partner-api-key --force-delete-without-recovery`, then deploy again |
