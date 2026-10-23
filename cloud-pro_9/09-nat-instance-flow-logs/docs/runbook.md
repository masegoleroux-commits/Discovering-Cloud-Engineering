# Runbook – 09 NAT Instance + Flow Logs

Full walkthrough: [START-HERE.md](START-HERE.md).

```bash
aws sts get-caller-identity                 # admin user, not root
./scripts/deploy.sh                         # confirm the SNS email; wait 3 minutes
./scripts/test_egress.sh                    # app's public IP = NAT Elastic IP
./scripts/test_rejected.sh                  # deliberate blocked connections
./scripts/destroy.sh
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=nat-egress \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `InvalidInstanceId` from `send-command` | App's SSM agent not registered yet (it needs the NAT working first) | Wait 5 minutes and retry |
| `Seen by the internet as:` is empty | NAT not forwarding | Session Manager on the NAT: `sudo iptables -t nat -L -n -v`; check `/var/log/cloud-init-output.log` |
| No Flow Log records | First batch takes 1–5 minutes | Wait |
