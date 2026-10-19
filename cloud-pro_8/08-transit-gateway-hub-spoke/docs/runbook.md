# Runbook – 08 Transit Gateway Hub-and-Spoke

Full walkthrough: [START-HERE.md](START-HERE.md).

```bash
aws sts get-caller-identity                 # admin user, not root
./scripts/deploy.sh
./scripts/run_analysis.sh                   # ~$0.30 per run
./scripts/destroy.sh                        # same day: TGW attachments bill hourly
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=tgw-hub \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| Attachment stuck in `pending` | Normal for 1–3 minutes | Wait |
| Analysis says `app-to-shared False` | Propagation into `spokes-rt` missing | Check `aws_ec2_transit_gateway_route_table_propagation.into_spokes` |
| `destroy` slow on attachments | TGW detaches one at a time | Wait up to 10 minutes |
