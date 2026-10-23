# Runbook – 10 Zero-Internet Workload with VPC Endpoints

Full walkthrough: [START-HERE.md](START-HERE.md).

```bash
aws sts get-caller-identity                 # admin user, not root
./scripts/deploy.sh                         # wait 3-5 minutes for the SSM agent to register
./scripts/run_tests.sh
./scripts/test_from_laptop.sh               # expect AccessDenied
./scripts/destroy.sh
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=private-endpoints \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `InvalidInstanceId` from `send-command` | SSM agent not registered yet | Wait 5 minutes; check the 3 interface endpoints are **Available** |
| Test 2 or 3 fails with AccessDenied | Endpoint or bucket policy mismatch | Check the endpoint ID in the bucket policy matches `s3_endpoint_id` |
| Test 4 says READ SUCCEEDED | Endpoint policy not applied | Check `aws_vpc_endpoint.s3` policy in the console |
