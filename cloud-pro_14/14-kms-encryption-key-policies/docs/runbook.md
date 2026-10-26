# Runbook – 14 KMS Encryption and Key Policies

Full walkthrough: [START-HERE.md](START-HERE.md). Test cases: [TEST-CASES.md](TEST-CASES.md).

```bash
aws sts get-caller-identity                       # admin user, not root
terraform -chdir=infrastructure test              # offline test cases (free)
./scripts/deploy.sh
./scripts/run_tests.sh
./scripts/destroy.sh                              # same day
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=kms-demo \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `TC-14-L03 key admin could read the data!` | The key policy gives the admin role Decrypt | Check `kms.tf`: the admin statement must not include `kms:Decrypt` or `kms:*`; run `terraform -chdir=infrastructure test` |
| `AccessDenied` on `sts:AssumeRole` in the script | Your user can't assume the demo roles | Use your admin user (`aws sts get-caller-identity`) |
| `alias/kms-demo-dev already exists` on deploy | A previous key is still pending deletion with its alias | `aws kms delete-alias --alias-name alias/kms-demo-dev`, then deploy again |
