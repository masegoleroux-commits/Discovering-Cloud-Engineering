# Project 06 – Event-Driven CSV Processing Pipeline: Complete Guide

**Thursday 15 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 3–4 hours. **Estimated cost: well under $0.01** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

All the order data in this project is **synthetic** (made up). Say so in your screenshot captions.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Run the tests and push the code | No |
| 4 | Check your AWS connection | No |
| 5 | Deploy to AWS | **Yes – but costs well under $0.01** |
| 6 | Show the workflow | Yes |
| 7 | Run it with a good and a bad file | Yes |
| 8 | Show the results | Yes |
| 9 | Prove re-uploads are safe | Yes |
| 10 | Tear it all down | Yes |
| 11 | Diagram, final push, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_6/06-event-driven-csv-pipeline/docs/screenshots/` with **exactly** that file name. This project has **11 images** in total.

**Before your first project:** do *Part A – Make your AWS account safe* in the root `BUILD-GUIDE.md` (MFA, a $5 budget alert, an admin user and access keys). Already did Project 03? Then your tools, VS Code and AWS connection are ready.

---
## Part 1 – Check your tools

Open VS Code, press ``Ctrl + ` `` for the terminal (it should say **Git Bash**), and run:

```bash
git --version
aws --version
terraform -version
```

Each line should print a version number. If one doesn't, see Part 1 of the Project 03 guide (`cloud-pro_3/03-serverless-notes-api/docs/START-HERE.md`).

---
## Part 2 – Add the Project 06 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-06-csv-pipeline.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
├── .github/workflows/
│   └── 06-csv-pipeline-ci.yml               ← runs the tests and terraform validate on GitHub
└── cloud-pro_6/06-event-driven-csv-pipeline/
    ├── README.md
    ├── requirements-dev.txt  pytest.ini
    ├── src/validate/app.py                  ← Lambda 1: checks the CSV
    ├── src/load/app.py                      ← Lambda 2: writes rows to DynamoDB
    ├── tests/                               ← 13 tests + synthetic CSV files in tests/data/
    ├── infrastructure/                      ← S3, EventBridge, Step Functions, Lambda, DynamoDB, SQS, SNS
    │   └── templates/pipeline.asl.json.tftpl ← the Step Functions workflow
    ├── scripts/                             ← deploy, upload_samples, check_results, destroy
    └── docs/                                ← START-HERE, runbook, ADRs, diagram, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_6/06-event-driven-csv-pipeline
pwd
```

`pwd` should end with `06-event-driven-csv-pipeline`. **Every command from here on runs from this folder** unless it says otherwise.

---
## Part 3 – Run the tests and push the code (free)

### 3.1 Tests

```bash
python -m venv .venv
source .venv/Scripts/activate      # Windows Git Bash
# source .venv/bin/activate        # Mac / Linux
pip install -r requirements-dev.txt
pytest -v
```

Expected: **`13 passed`**. The tests use moto, a fake AWS that runs on your computer, so they cost nothing.

📸 **`01-pytest-pass.png`**

### 3.2 Look at the test files

Open `tests/data/valid_orders.csv` and `tests/data/invalid_orders.csv` in VS Code. The invalid file breaks **5 rules on purpose**: a bad email, a negative amount, a duplicate order ID, an unsupported currency (JPY) and a wrong date format. You'll see the pipeline catch all five.

### 3.3 Push the code (only Project 06)

This push only runs the tests on GitHub; it doesn't touch AWS.

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/06-csv-pipeline-ci.yml cloud-pro_6
git status        # only these files; no tfvars, tfstate or .venv
git commit -m "feat(06): event-driven CSV pipeline with Step Functions"
git push
cd cloud-pro_6/06-event-driven-csv-pipeline
```

On GitHub, **Actions → 06 CSV Pipeline CI** should go green in 1–2 minutes.

---
## Part 4 – Check your AWS connection

### 4.1 Make sure VS Code is signed in as your admin user

```bash
aws sts get-caller-identity
```

The `Arn` must end in `:user/masego-admin` (or whatever you named your admin user). If it ends in `:root`, or you get an error, follow *Part A* in the root `BUILD-GUIDE.md` first.

### 4.2 Check the region in the console

Sign in to the AWS console with your admin user's sign-in URL and check the region in the top right says **Europe (Stockholm) eu-north-1**. Your account only allows this region, and resources in other regions won't appear on screen.

---
## Part 5 – Deploy to AWS

### 5.1 Fill in your settings

```bash
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
```

Open `infrastructure/terraform.tfvars` in VS Code and set:

```hcl
owner       = "masegoleroux-commits"
alert_email = "your-real-email@example.com"
```


Use a real email you can open now. AWS sends a **Confirm subscription** email after the deploy, and alerts only arrive once you click it.

Save (`Ctrl + S`). `.gitignore` keeps this file off GitHub.

### 5.2 Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Wait for `Apply complete! Resources: 27 added` and outputs including `upload_bucket`, `state_machine_arn`, `dead_letter_queue_url` and `orders_table`.

📸 **`02-terraform-apply.png`**

**Check your inbox now** and click **Confirm subscription** in the AWS Notifications email.

---

## Part 6 – Show the workflow

**Step Functions** → State machines → `csv-pipeline-dev-pipeline` → **Edit** (or the **Definition** tab) → **Design** view. You'll see the six states as a graph: ValidateFile → LoadOrders → NotifySuccess, and the failure branch SendToDeadLetterQueue → NotifyFailure → MarkFailed.

📸 **`03-state-machine-definition.png`**

Close the editor **without saving** (Terraform owns the definition).

---

## Part 7 – Run it with a good and a bad file

```bash
./scripts/upload_samples.sh
sleep 30
./scripts/check_results.sh
```

Expected (DynamoDB drops trailing zeros, so `15.00` shows as `15`):

```
== Latest executions
|  <id>  |  SUCCEEDED |
|  <id>  |  FAILED    |
== Rows in csv-pipeline-dev-orders
|  ORD-1001 |  249.99  |  ZAR |
|  ORD-1002 |  15      |  USD |
|  ORD-1003 |  1200.5  |  EUR |
== Dead-letter queue (message stays in the queue)
{ "bucket": ..., "key": "incoming/invalid_orders.csv", "error": { "Error": "ValidationError", "Cause": ... } }
```

Now show both runs in the console: **Step Functions** → `csv-pipeline-dev-pipeline` → **Executions**.

| # | Open | What must be visible | Save as |
|---|------|----------------------|---------|
| 📸 | The **SUCCEEDED** execution → **Graph view** | Green path: ValidateFile → LoadOrders → NotifySuccess | `04-execution-success.png` |
| 📸 | The **FAILED** execution → **Graph view** → click **ValidateFile** → **Output** or **Exception** | The caught error, then SendToDeadLetterQueue → NotifyFailure → MarkFailed, with the list of problems ending "(5 problems total)" | `05-execution-rejected.png` |

Caption the second one "Deliberately broken synthetic file".

---

## Part 8 – Show the results

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **DynamoDB** → Tables → `csv-pipeline-dev-orders` → **Explore table items** | The 3 order rows | `06-dynamodb-items.png` |
| 📸 | **SQS** → Queues → `csv-pipeline-dev-failed` → **Send and receive messages** → **Poll for messages** → open the message | The body with `error.Cause`. **Blur the account ID** in the bucket name | `07-dead-letter-queue.png` |
| 📸 | Your email inbox | The **CSV loaded** and **CSV rejected** emails. **Blur your email address** | `08-emails.png` |

---

## Part 9 – Prove re-uploads are safe

Upload the good file again under a new name:

```bash
BUCKET=$(terraform -chdir=infrastructure output -raw upload_bucket)
aws s3 cp tests/data/valid_orders.csv "s3://$BUCKET/incoming/valid_orders_again.csv"
sleep 30
aws dynamodb scan --table-name csv-pipeline-dev-orders --select COUNT
```

Expected: `"Count": 3`, **not 6**. The loader overwrites rows by `order_id`, so the same orders never appear twice.

📸 **`09-idempotent-reload.png`** – the new SUCCEEDED execution next to the `"Count": 3` output.

### Screenshot rules

- Windows: `Win + Shift + S` · Mac: `Cmd + Shift + 4`
- Save as **PNG**, cropped to the useful part.
- **Blur** the 12-digit account ID, your email, public IPs (optional) and any access keys. Never screenshot the `aws configure` answers or the access key CSV.
- Label deliberate tests and synthetic data in your README captions.

---

## Part 10 – Tear it all down (same day)

```bash
./scripts/destroy.sh
```

Wait for `Destroy complete!`

📸 **`10-terraform-destroy.png`**

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=csv-pipeline \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

An empty table means you're clean. Deleted items can linger in this list for a few minutes; if something is still there after an hour, run `./scripts/destroy.sh` again.

---
## Part 11 – Diagram, final push, mark complete

### 11.1 Architecture image

In VS Code, open `docs/architecture.drawio` (the Draw.io extension shows the diagram), export it as **PNG**, and save it as:

📸 **`docs/screenshots/00-architecture.png`**

(Or open the file at https://app.diagrams.net → **File → Export as → PNG**.)

### 11.2 Check you have every image

```bash
ls docs/screenshots/
```

You should see:

```
00-architecture.png              04-execution-success.png   08-emails.png
01-pytest-pass.png               05-execution-rejected.png  09-idempotent-reload.png
02-terraform-apply.png           06-dynamodb-items.png      10-terraform-destroy.png
03-state-machine-definition.png  07-dead-letter-queue.png
```

### 11.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 11.4 Push only Project 06

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/06-csv-pipeline-ci.yml cloud-pro_6
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "docs(06): add screenshots, diagram and lessons learned"
git push
```

### 11.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 06's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 06 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| Fewer than 13 tests run, or `ModuleNotFoundError: conftest` | Tests run from the wrong folder | Run `pytest` from the project folder (where `pytest.ini` is) |
| Upload does nothing | File not under `incoming/`, or EventBridge off on the bucket | Check the S3 key starts with `incoming/` |
| Rule matches but no execution | EventBridge role can't start the state machine | **EventBridge** → Rules → `csv-pipeline-dev-csv-uploaded` → **Monitoring** → look for `FailedInvocations` |
| State machine fails to create | Log-delivery permissions missing | Check the `logs:*Delivery*` actions on the SFN role in `stepfunctions.tf` |
| `check_results.sh` shows no rows | Executions still running | Wait another 30 seconds and run it again |
| `Float types are not supported` in the load Lambda | Amount passed as a float | `to_item` must use `Decimal` (it does; check you didn't edit it) |
| No emails | Subscription not confirmed | **SNS → Subscriptions** must say **Confirmed** |
| `chmod: command not found` or `'.' is not recognized` | You're in PowerShell, not Git Bash | Open a new terminal and pick **Git Bash** in the dropdown |
| `No valid credential sources found` / `InvalidClientTokenId` | Access key missing, mistyped or deactivated | Create a new access key for your admin user (BUILD-GUIDE Part A6) and run `aws configure` |
| `No value for required variable` | `terraform.tfvars` missing, misnamed (`.txt`), or a value left out | Repeat the "Fill in your settings" step; the file must be in `infrastructure/` |
| `bad interpreter: /bin/bash^M` | Windows line endings | `sed -i 's/\r$//' scripts/*.sh` |
| `AccessDenied` / `not authorized` | You're signed in as a user without admin rights | Check `aws sts get-caller-identity`; the user needs `AdministratorAccess` |
| An unexpected charge on your bill | Something was left running | Run the project's `./scripts/destroy.sh`, then the leftover check in the BUILD-GUIDE |
| `git push` rejected: "fetch first" | GitHub has changes you don't | `git pull --rebase` then `git push` |

If none of these match, copy the exact error text and send it to me.

## Cost safety net

- Your **$5 budget alert** (BUILD-GUIDE Part A3) emails you if spending climbs.
- After destroying, run the **leftover check** in the teardown part above.
- Next morning, look at **Billing → Cost Explorer** (charges appear up to a day late).
