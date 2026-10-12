# Runbook – 03 Serverless Notes API

Budget about 3 hours. Every 📸 marks a screenshot; save it in `docs/screenshots/` with the exact name shown.

## 0. Before you start

- [ ] KodeKloud playground started and `aws sts get-caller-identity` works (see the root `BUILD-GUIDE.md`)
- [ ] Terraform, Python 3.12 and Git installed

## 1. Run the tests locally

```bash
cd cloud-pro_3/03-serverless-notes-api
python -m venv .venv
source .venv/bin/activate          # Windows Git Bash: source .venv/Scripts/activate
pip install -r requirements-dev.txt
pytest -v
```

Expected: `9 passed`.

📸 **`01-pytest-pass.png`**: the terminal showing every test name and `9 passed`.

## 2. Deploy

```bash
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
# edit terraform.tfvars and set: owner = "your-github-handle"
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Expected: `Apply complete! Resources: 13 added` (the exact count may differ slightly) and an `api_base_url` output.

📸 **`02-terraform-apply.png`**: the end of the output with `Apply complete!` and the outputs.

## 3. Check it in the AWS console

1. **API Gateway → APIs → `notes-api-dev-http-api` → Routes.** You should see the 4 routes.
   📸 **`03-api-gateway-routes.png`**
2. **Lambda → Functions → `notes-api-dev-handler` → Configuration → General configuration.** Memory 128 MB, timeout 5 sec.
   📸 **`04-lambda-config.png`**
3. **IAM → Roles → `notes-api-dev-lambda-role` → Permissions → `notes-api-dev-lambda-policy` → JSON.** It shows the 4 actions on one table ARN.
   📸 **`05-iam-policy.png`**: **blur the 12-digit account ID** inside the ARNs.

## 4. Smoke test

```bash
./scripts/smoke_test.sh
```

Expected: a created note, a list, the single note, `HTTP 400` for the empty body, and `HTTP 204` for the delete. This uses about 5 of your 300 Lambda invocations per hour.

📸 **`06-smoke-test.png`**: the full terminal output.

Create one more note so there is something to see in the table:

```bash
API=$(terraform -chdir=infrastructure output -raw api_base_url)
curl -s -X POST "$API/notes" -H 'Content-Type: application/json' -d '{"title":"Portfolio demo note"}'
```

## 5. Data and logs

1. **DynamoDB → Tables → `notes-api-dev-notes` → Explore table items.**
   📸 **`07-dynamodb-items.png`**
2. **CloudWatch → Log groups → `/aws/lambda/notes-api-dev-handler` → newest log stream.** Expand a line to show the JSON (`request_received`, `note_created`).
   📸 **`08-cloudwatch-logs.png`**

## 6. CI pipeline

Commit and push this folder plus the root `.github/workflows/03-notes-api-ci.yml`.

```bash
git add cloud-pro_3 .github/workflows/03-notes-api-ci.yml
git commit -m "feat(03): serverless notes API with Terraform and tests"
git push
```

On GitHub, open **Actions → 03 Notes API CI** and wait for both jobs to go green.

📸 **`09-github-actions-ci.png`**: the run summary with both jobs ticked.

## 7. Tear down

```bash
./scripts/destroy.sh
```

📸 **`10-terraform-destroy.png`**: `Destroy complete!`

## 8. Architecture diagram

Open `docs/architecture.drawio` at app.diagrams.net, export it as PNG, and save it as **`docs/screenshots/00-architecture.png`**.

## 9. Finish

- [ ] All 11 images in `docs/screenshots/`
- [ ] Write the **Lessons learned** section in the README
- [ ] Main README status changed to ✅
- [ ] Commit and push

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `{"message":"Internal Server Error"}` | Missing Lambda permission | Check `aws_lambda_permission.apigw_invoke`, re-apply |
| HTTP 500 with a `request_id` | Code error | Search the log group for that `request_id` |
| `AccessDeniedException` in the logs | Action missing from the IAM policy | Add only that action, re-apply |
| HTTP 429 | Throttling working as intended | Wait a few seconds |
| `ProvisionedThroughputExceededException` | More than 1 write per second | Slow down; the sandbox fixes the table at 1 WCU |
| The function disappeared | Over 300 invocations in an hour | Re-run `deploy.sh`; find the script or loop that caused it |
