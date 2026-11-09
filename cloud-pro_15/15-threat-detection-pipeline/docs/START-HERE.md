# Project 15 – Threat Detection Pipeline: Complete Guide

**From the files to a finished project on GitHub, using VS Code and your own AWS account.** Redesigned on 27 October 2026 to use CloudTrail, because my organisation blocks GuardDuty and Security Hub (see [ADR 0003](adr/0003-cloudtrail-instead-of-guardduty.md)).

Total time: about 2–3 hours. **Estimated cost: free** (CloudTrail's first copy of management events is free) if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Run the unit and offline test cases | No (free) |
| 4 | Check your AWS connection | No |
| 5 | Deploy and confirm the email | **Yes – free** |
| 6 | Run the live test cases (deliberate test) | Yes |
| 7 | Show the rules, the alert and the tag | Yes |
| 8 | Tear it all down | Yes |
| 9 | Push only Project 15, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_15/15-threat-detection-pipeline/docs/screenshots/` with **exactly** that file name. This project has **8 images** in total.

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

This project also needs **Python 3.12** (`python --version`). On Windows, if `python3` isn't found, use `python`.

---
## Part 2 – Add the Project 15 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `projects-13-17.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
└── cloud-pro_15/15-threat-detection-pipeline/
    ├── README.md
    ├── requirements-dev.txt  pytest.ini
    ├── src/formatter/app.py  src/responder/app.py   ← plain-English alert, safe tag-only response
    ├── tests/                                       ← 14 unit test cases (AWS mocked)
    ├── infrastructure/                              ← CloudTrail trail, EventBridge rules, Lambdas, SNS, test security group
    │   └── tests/detection.tftest.hcl               ← 10 offline Terraform test cases
    ├── scripts/                                     ← deploy, run_tests, destroy
    └── docs/                                        ← START-HERE, TEST-CASES, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_15/15-threat-detection-pipeline
pwd
```

`pwd` should end with `15-threat-detection-pipeline`. **Every command from here on runs from this folder** unless it says otherwise.

---
## Part 3 – Run the test cases that need no AWS (free)

### 3.1 Unit test cases

```bash
python -m venv .venv
source .venv/Scripts/activate      # Windows Git Bash
# source .venv/bin/activate        # Mac / Linux
python -m pip install -r requirements-dev.txt
python -m pytest -v
```

Expected: **`14 passed`**. AWS is mocked, so nothing is created and nothing costs money.

### 3.2 Offline Terraform test cases

```bash
terraform -chdir=infrastructure init
terraform -chdir=infrastructure test
```

Expected: every `run "…"` line says `pass`, ending with **`Success! 10 passed, 0 failed.`** They apply the infrastructure against a mocked AWS and check the security rules, so a broken rule fails here, not in your account.

📸 **`01-offline-tests.png`** – the end of both outputs in one screenshot if you can.

Every test case has an ID (`TC-15-T01` and so on); the full list is in [TEST-CASES.md](TEST-CASES.md).

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

Use an email you can open now. AWS sends a **Confirm subscription** email after the deploy. **Check your junk folder** (Project 06's lesson) and mark it as not junk.

Don't add an `aws_region` line: the project already uses `eu-north-1`. Only if your account already has a CloudTrail trail **logging in eu-north-1**, also add `create_trail = false`.

Save (`Ctrl + S`). `.gitignore` keeps this file off GitHub.

### 5.2 Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Wait for `Apply complete!` and the outputs.

📸 **`02-terraform-apply.png`**

**Confirm the SNS subscription** in your inbox (or junk) now.

---

## Part 6 – Run the live test cases (deliberate test on a harmless security group)

```bash
./scripts/run_tests.sh
```

**What it does (deliberate test):** it opens port 22 to the whole internet (`0.0.0.0/0`) on the project's test security group. That group sits in an empty VPC and is attached to nothing, so nothing is exposed. CloudTrail records the change as a real event, EventBridge sends it to both functions, and the script waits up to 15 minutes for the alert and the tag. Then it closes the port again, even if you stop it with Ctrl + C. Expected:

```
== Project 15 live test cases
  PASS  TC-15-L01 trail threat-detect-dev-trail is logging
  PASS  TC-15-L02 all 3 detection rules are enabled
  PASS  TC-15-L03 deliberate test: port 22 opened to 0.0.0.0/0 on test group sg-... (attached to nothing)
  PASS  TC-15-L04 formatter sent a [DELIBERATE TEST] alert
  PASS  TC-15-L05 responder tagged sg-... with SecurityFinding
  PASS  TC-15-L06 the responder tagged the group but left the rule for a person to remove
  (deliberate test rule removed from sg-...)
  PASS  TC-15-L07 test group is closed again (no inbound rules)
```

Just after the trail is created, the first events can take longer to arrive. If L04 or L05 fail with "not in time", wait 5 minutes and run the script again.

📸 **`03-live-tests.png`** – caption it "Deliberate test: harmless security group opened, then closed".

---

## Part 7 – Show the rules, the alert and the tag

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **Amazon EventBridge** → **Rules** | The three `threat-detect-dev-...` rules, **Enabled** | `04-eventbridge-rules.png` |
| 📸 | Your inbox (check **junk**) | The `[DELIBERATE TEST] HIGH: AuthorizeSecurityGroupIngress ...` email. Blur your address and the account ID. This is TC-15-M01 | `05-alert-email.png` |
| 📸 | **EC2** → **Security Groups** → `threat-detect-dev-canary-sg` → **Tags** | The `SecurityFinding` tag added by the responder | `06-security-group-tag.png` |
| 📸 | **CloudTrail** → **Event history**, filter *Event name* = `AuthorizeSecurityGroupIngress` | The event the script caused: who, when, which group | `07-cloudtrail-event.png` |

### Screenshot rules

- Windows: `Win + Shift + S` · Mac: `Cmd + Shift + 4`
- Save as **PNG**, cropped to the useful part.
- **Blur** the 12-digit account ID, your email, public IPs (optional) and any access keys. Never screenshot the `aws configure` answers or the access key CSV.
- Label deliberate tests and synthetic data in your README captions.

---

## Part 8 – Tear it all down (same day)

```bash
./scripts/destroy.sh
```

Wait for `Destroy complete!`

📸 **`08-terraform-destroy.png`**

Destroy deletes this project's own trail, so you may get one last **`CRITICAL: DeleteTrail`** email. That's expected: it's exactly what the rule watches for. If you used `create_trail = false`, your existing trail is left as it was.

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=threat-detect \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

An empty table means you're clean. Deleted items can linger in this list for a few minutes; if something is still there after an hour, run `./scripts/destroy.sh` again.

---
## Part 9 – Final push, mark complete

### 9.1 Check you have every image

```bash
ls docs/screenshots/
```

You should see:

```
01-offline-tests.png
02-terraform-apply.png
03-live-tests.png
04-eventbridge-rules.png
05-alert-email.png
06-security-group-tag.png
07-cloudtrail-event.png
08-terraform-destroy.png
```

The architecture diagram is written in Mermaid inside the README, so GitHub draws it for you: there's no diagram image to export.

### 9.2 Record your results

- In `docs/TEST-CASES.md`, fill in **My result** for each live test case you ran (for example `PASS 26 Oct`). Only fill in what you actually ran.
- In `README.md`, change the status line to say it was deployed and tested, and write **Lessons Learned**: what broke, the exact error, the fix.

### 9.3 Push only Project 15

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/security-track-ci.yml cloud-pro_15
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.test-work` file appears. Then:

```bash
git commit -m "feat(15): CloudTrail threat detection with plain-English alerts and safe response"
git push
```

On GitHub, **Actions → Security track CI** should go green: it runs this project's unit and offline test cases.

### 9.4 Mark it complete in your main README

In the **main** `README.md`, change project 15's status to `✅ Complete (torn down to avoid cost)`, then commit and push.

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `explicit deny in a service control policy` | Your organisation blocks that service | Copy the exact error and send it to me; GuardDuty and Security Hub are already designed out |
| `TC-15-L04 no alert yet` | CloudTrail events can take several minutes to reach EventBridge, especially just after the trail is created | Wait 5 minutes and run `./scripts/run_tests.sh` again |
| `TrailAlreadyExists` or a limit on trails | A trail with that name, or the maximum number of trails, already exists | If a trail is already logging in eu-north-1, set `create_trail = false` |
| `Python was not found` or `pytest: command not found` | The `.venv` isn't switched on | `source .venv/Scripts/activate`, then use `python -m pytest -v` |
| No email | Subscription not confirmed, or in junk | **SNS → Subscriptions** must say **Confirmed**; mark the sender as not junk |
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
