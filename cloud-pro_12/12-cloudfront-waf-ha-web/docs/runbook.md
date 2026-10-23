# Runbook – 12 CloudFront + WAF + HA Web Tier

Full walkthrough: [START-HERE.md](START-HERE.md).

```bash
aws sts get-caller-identity                 # admin user, not root
./scripts/deploy.sh                         # 10-15 minutes
./scripts/test_access.sh
./scripts/test_rate_limit.sh                # deliberate
./scripts/test_self_healing.sh              # deliberate
./scripts/destroy.sh                        # 10-15 minutes
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=edge-web \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| CloudFront returns 502/504 | No healthy targets yet | Wait 3–5 minutes after apply |
| Targets keep failing health checks | Nginx didn't install | EC2 → instance → Actions → Monitor → **Get system log** |
| Site returns the "Direct access is not allowed" 403 | Header mismatch | Run `./scripts/deploy.sh` again so CloudFront and the ALB rule share the same secret |
