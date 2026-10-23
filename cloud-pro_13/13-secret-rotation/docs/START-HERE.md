# Project 13 – Automatic Secret Rotation: Complete Guide

**Monday 26 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 2–3 hours. **Estimated cost: under $0.05** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Run the unit and offline test cases | No (free) |
| 4 | Check your AWS connection | No |
| 5 | Deploy | **Yes – cents** |
| 6 | Show the rotation setup | Yes |
| 7 | Run the live test cases | Yes |
| 8 | CloudTrail evidence | Yes |
| 9 | Tear it all down | Yes |
| 10 | Push only Project 13, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_13/13-secret-rotation/docs/screenshots/` with **exactly** that file name. This project has **8 images** in total.

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
## Part 2 – Add the Project 13 files

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
└── cloud-pro_13/13-secret-rotation/
    ├── README.md
    ├── requirements-dev.txt  pytest.ini
    ├── src/rotation/app.py              ← the 4-step rotation function
    ├── src/api/app.py  src/client/app.py ← the pretend partner API and the app that calls it
    ├── tests/                           ← 13 unit test cases (AWS mocked with moto)
    ├── infrastructure/                  ← secret, rotation schedule, Lambdas, key registry, IAM
    │   └── tests/rotation.tftest.hcl    ← 8 offline Terraform test cases
    ├── scripts/                         ← deploy, run_tests, destroy
    └── docs/                            ← START-HERE, TEST-CASES, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_13/13-secret-rotation
pwd
```

`pwd` should end with `13-secret-rotation`. **Every command from here on runs from this folder** unless it says otherwise.

---
## Part 3 – Run the test cases that need no AWS (free)

### 3.1 Unit test cases

```bash
python -m venv .venv
source .venv/Scripts/activate      # Windows Git Bash
# source .venv/bin/activate        # Mac / Linux
pip install -r requirements-dev.txt
pytest -v
```

Expected: **`13 passed`**. AWS is mocked, so nothing is created and nothing costs money.

### 3.2 Offline Terraform test cases

```bash
terraform -chdir=infrastructure init
terraform -chdir=infrastructure test
```

Expected: every `run "…"` line says `pass`, ending with **`Success! 8 passed, 0 failed.`** They plan the infrastructure against a mocked AWS and check the security rules, so a broken rule fails here, not in your account.

📸 **`01-offline-tests.png`** – the end of both outputs in one screenshot if you can.

Every test case has an ID (`TC-13-T01` and so on); the full list is in [TEST-CASES.md](TEST-CASES.md).

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
```

Save (`Ctrl + S`). `.gitignore` keeps this file off GitHub.

### 5.2 Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Wait for `Apply complete!` and the outputs.

📸 **`02-terraform-apply.png`**

---

## Part 6 – Show the rotation setup

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **Secrets Manager** → `secret-rotation-dev/partner-api-key` → **Rotation** tab | Rotation **Enabled**, every 7 days, Lambda `secret-rotation-dev-rotation` | `03-rotation-config.png` |

---

## Part 7 – Run the live test cases

```bash
./scripts/run_tests.sh
```

It rotates the key **twice** (about 1 minute) and checks the app keeps working. Expected:

```
== Project 13 live test cases
  PASS  TC-13-L01 client calls the API with the current key
  PASS  TC-13-L02 rotation 1 completed (create, set, test, finish)
  PASS  TC-13-L03 the key value changed
  PASS  TC-13-L04 previous key still accepted
  PASS  TC-13-L05 client still works after rotation
  PASS  TC-13-L06 key from two rotations ago is revoked
  PASS  TC-13-L07 previous key (rotation 1) still accepted
  PASS  TC-13-L08 unknown key refused
  PASS  TC-13-L09 registry contains hashes only

Result: 9 passed, 0 failed
```

📸 **`04-live-tests.png`**

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **CloudWatch** → Log groups → `/aws/lambda/secret-rotation-dev-rotation` → newest stream | The lines for `createSecret`, `setSecret`, `testSecret`, `finishSecret` | `05-rotation-logs.png` |
| 📸 | **Secrets Manager** → the secret → **Versions** (or run `aws secretsmanager list-secret-version-ids --secret-id secret-rotation-dev/partner-api-key`) | One version `AWSCURRENT`, one `AWSPREVIOUS` | `06-secret-versions.png` |

Never screenshot the secret **value**.

---

## Part 8 – CloudTrail evidence (manual check TC-13-M01)

CloudTrail events take about 5–15 minutes to appear. **CloudTrail** → **Event history** → filter **Event name** = `RotateSecret`.

📸 **`07-cloudtrail-rotatesecret.png`** – two `RotateSecret` events with your user name. Blur the account ID.

### Screenshot rules

- Windows: `Win + Shift + S` · Mac: `Cmd + Shift + 4`
- Save as **PNG**, cropped to the useful part.
- **Blur** the 12-digit account ID, your email, public IPs (optional) and any access keys. Never screenshot the `aws configure` answers or the access key CSV.
- Label deliberate tests and synthetic data in your README captions.

---

## Part 9 – Tear it all down (same day)

```bash
./scripts/destroy.sh
```

Wait for `Destroy complete!`

📸 **`08-terraform-destroy.png`**

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=secret-rotation \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

An empty table means you're clean. Deleted items can linger in this list for a few minutes; if something is still there after an hour, run `./scripts/destroy.sh` again.

---
## Part 10 – Final push, mark complete

### 10.1 Check you have every image

```bash
ls docs/screenshots/
```

You should see:

```
01-offline-tests.png
02-terraform-apply.png
03-rotation-config.png
04-live-tests.png
05-rotation-logs.png
06-secret-versions.png
07-cloudtrail-rotatesecret.png
08-terraform-destroy.png
```

The architecture diagram is written in Mermaid inside the README, so GitHub draws it for you: there's no diagram image to export.

### 10.2 Record your results

- In `docs/TEST-CASES.md`, fill in **My result** for each live test case you ran (for example `PASS 26 Oct`). Only fill in what you actually ran.
- In `README.md`, change the status line to say it was deployed and tested, and write **Lessons Learned**: what broke, the exact error, the fix.

### 10.3 Push only Project 13

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/security-track-ci.yml cloud-pro_13
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.test-work` file appears. Then:

```bash
git commit -m "feat(13): automatic secret rotation with tested zero-downtime overlap"
git push
```

On GitHub, **Actions → Security track CI** should go green: it runs this project's unit and offline test cases.

### 10.4 Mark it complete in your main README

In the **main** `README.md`, change project 13's status to `✅ Complete (torn down to avoid cost)`, then commit and push.

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `TC-13-L02 rotation 1 did not finish` | The rotation function failed a step | Open its log group; the error names the step. Fix, then `aws secretsmanager cancel-rotate-secret --secret-id secret-rotation-dev/partner-api-key` and re-run |
| `pytest` can't import `moto` | Dev requirements not installed | `pip install -r requirements-dev.txt` inside your `.venv` |
| `A secret with this name is already scheduled for deletion` on deploy | A previous run's secret is still in its recovery window | `aws secretsmanager delete-secret --secret-id secret-rotation-dev/partner-api-key --force-delete-without-recovery`, then deploy again |
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
