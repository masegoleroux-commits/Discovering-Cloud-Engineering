# Runbook – 04 VPC + Hardened Web Server

The short operations card. For the full first-time walkthrough with every screenshot, see [START-HERE.md](START-HERE.md).

## Before you start

```bash
aws sts get-caller-identity      # Arn must end in :user/<your-admin-user>, never :root
cp -n infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars   # then fill it in
```

## Deploy and verify

```bash
./scripts/deploy.sh                                   # then confirm the SNS email
# wait 3-5 minutes for Nginx and the CloudWatch agent to install
./scripts/verify.sh                                   # 200, Server: nginx (no version), port 22 closed
aws ssm start-session --target "$(terraform -chdir=infrastructure output -raw instance_id)"
```

## Tear down (same day)

```bash
./scripts/destroy.sh
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=vpc-web \
  --query 'ResourceTagMappingList[].ResourceARN' --output table      # should be empty
```

## Common problems

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Page doesn't load | Start-up script still running | Wait 5 min; then `sudo tail -50 /var/log/cloud-init-output.log` in a session |
| `TargetNotConnected` | SSM agent not registered yet | Wait 5 min; check the role has `AmazonSSMManagedInstanceCore` |
| No alarm email | Subscription not confirmed | SNS → Subscriptions must say **Confirmed** |
| `ExpiredToken` / `InvalidClientTokenId` | Access key deactivated or mistyped | Create a new key for your admin user and run `aws configure` |
| `No value for required variable` | `terraform.tfvars` missing or incomplete | Copy the example file and fill it in |
