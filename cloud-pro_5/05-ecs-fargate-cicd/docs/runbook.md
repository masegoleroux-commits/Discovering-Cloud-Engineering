# Runbook – 05 Containerised App on ECS Fargate

The short operations card. For the full first-time walkthrough with every screenshot, see [START-HERE.md](START-HERE.md).

## Before you start

```bash
aws sts get-caller-identity      # Arn must end in :user/<your-admin-user>, never :root
cp -n infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars   # then fill it in
```

## Deploy and verify

```bash
pip install -r requirements-dev.txt && pytest -v      # 3 passed
./scripts/bootstrap.sh                                # first deploy only (Docker Desktop must be running)
terraform -chdir=infrastructure output -raw github_deploy_role_arn   # save as GitHub variable AWS_DEPLOY_ROLE_ARN
git push                                              # releases through GitHub Actions
./scripts/watch_versions.sh                           # watch a rolling deploy
```

## Tear down (same day)

```bash
./scripts/destroy.sh
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=container-app \
  --query 'ResourceTagMappingList[].ResourceARN' --output table      # should be empty
```

## Common problems

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `CannotPullContainerError` | Task can't reach ECR | Check `assign_public_ip = true` and the task egress rule |
| `exec format error` | ARM image built on Apple Silicon | Build with `--platform linux/amd64` (bootstrap does this) |
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Repo/branch doesn't match the role's trust policy, or `id-token: write` missing | Check `github_repository` in tfvars and that you pushed to `main` |
| `ExpiredToken` / `InvalidClientTokenId` | Access key deactivated or mistyped | Create a new key for your admin user and run `aws configure` |
| `No value for required variable` | `terraform.tfvars` missing or incomplete | Copy the example file and fill it in |
