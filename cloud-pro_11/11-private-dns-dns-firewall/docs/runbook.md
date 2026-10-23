# Runbook – 11 Private DNS + DNS Firewall

Full walkthrough: [START-HERE.md](START-HERE.md).

```bash
aws sts get-caller-identity                 # admin user, not root
./scripts/deploy.sh                         # wait 3 minutes for the client to install dig
./scripts/test_dns.sh
./scripts/test_from_laptop.sh
./scripts/destroy.sh
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=private-dns \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `dig: command not found` | Start-up script still installing bind-utils | Wait 2 minutes |
| `doubleclick.net` still resolves | Firewall association not active yet | Wait 1–2 minutes; check the rule group association is **Complete** |
| Query log group empty | Logging takes a few minutes to start | Wait 5 minutes and run the tests again |
