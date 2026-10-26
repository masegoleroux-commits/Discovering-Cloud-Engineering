# Project 14 – KMS Encryption and Key Policies: Complete Guide

**Tuesday 27 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 2 hours. **Estimated cost: about $0.05** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Run the offline test cases | No (free) |
| 4 | Check your AWS connection | No |
| 5 | Deploy | **Yes – cents** |
| 6 | Show the key and its policy | Yes |
| 7 | Run the live test cases | Yes |
| 8 | CloudTrail evidence | Yes |
| 9 | Tear it all down | Yes |
| 10 | Push only Project 14, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_14/14-kms-encryption-key-policies/docs/screenshots/` with **exactly** that file name. This project has **8 images** in total.

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
## Part 2 – Add the Project 14 files

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
└── cloud-pro_14/14-kms-encryption-key-policies/
    ├── README.md
    ├── infrastructure/                       ← KMS key + key policy, S3, DynamoDB, SQS, two IAM roles
    │   └── tests/key_policy.tftest.hcl       ← 7 offline Terraform test cases
    ├── scripts/                              ← deploy, run_tests, destroy
    └── docs/                                 ← START-HERE, TEST-CASES, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_14/14-kms-encryption-key-policies
pwd
```

`pwd` should end with `14-kms-encryption-key-policies`. **Every command from here on runs from this folder** unless it says otherwise.

---
## Part 3 – Run the test cases that need no AWS (free)

### 3.1 Offline Terraform test cases

```bash
terraform -chdir=infrastructure init
terraform -chdir=infrastructure test
```

Expected: every `run "…"` line says `pass`, ending with **`Success! 7 passed, 0 failed.`** They plan the infrastructure against a mocked AWS and check the security rules, so a broken rule fails here, not in your account.

📸 **`01-offline-tests.png`** – the end of both outputs in one screenshot if you can.

Every test case has an ID (`TC-14-T01` and so on); the full list is in [TEST-CASES.md](TEST-CASES.md).

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

## Part 6 – Show the key and its policy

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **KMS** → **Customer managed keys** → `alias/kms-demo-dev` → **Key policy** tab (switch to policy view) | The `KeyAdministratorsManageOnly` and `KeyUsersUseOnly` statements | `03-key-policy.png` |
| 📸 | **S3** → the `kms-demo-dev-data-…` bucket → **Properties** → **Default encryption** | SSE-KMS with the project key, **Bucket Key enabled** | `04-bucket-encryption.png` |

---

## Part 7 – Run the live test cases

```bash
./scripts/run_tests.sh
```

The script assumes the key-admin and app roles in turn. Expected:

```
== Project 14 live test cases
  PASS  TC-14-L01 object encrypted with the project key (SSE-KMS)
  PASS  TC-14-L02 app role can read the data
  PASS  TC-14-L03 key admin refused by the KMS key policy (deliberate test)
  PASS  TC-14-L04 key admin can manage the key (rotation status: enabled)
  PASS  TC-14-L05 key admin cannot create a grant for themselves
  PASS  TC-14-L06 app role writes to the KMS-encrypted table
  PASS  TC-14-L07 app role sends to the KMS-encrypted queue
  PASS  TC-14-L08 table encrypted with the project key

Result: 8 passed, 0 failed
```

📸 **`05-live-tests.png`** – caption it "Deliberate test: key admin refused".

---

## Part 8 – CloudTrail evidence

After 5–15 minutes: **CloudTrail** → **Event history** → **Event name** = `Decrypt`. Open the event with an **error code** `AccessDenied`: its `userIdentity` is the key-admin role.

📸 **`06-cloudtrail-decrypt.png`** – blur the account ID.

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

KMS never deletes a key immediately. After destroy it shows **Pending deletion** for 7 days, so nothing that still needs it is lost by mistake.

📸 **`07-key-pending-deletion.png`** – **KMS** → **Customer managed keys**: the key with status *Pending deletion*.

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=kms-demo \
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
03-key-policy.png
04-bucket-encryption.png
05-live-tests.png
06-cloudtrail-decrypt.png
07-key-pending-deletion.png
08-terraform-destroy.png
```

The architecture diagram is written in Mermaid inside the README, so GitHub draws it for you: there's no diagram image to export.

### 10.2 Record your results

- In `docs/TEST-CASES.md`, fill in **My result** for each live test case you ran (for example `PASS 26 Oct`). Only fill in what you actually ran.
- In `README.md`, change the status line to say it was deployed and tested, and write **Lessons Learned**: what broke, the exact error, the fix.

### 10.3 Push only Project 14

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/security-track-ci.yml cloud-pro_14
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.test-work` file appears. Then:

```bash
git commit -m "feat(14): KMS key policy separating key admins from key users"
git push
```

On GitHub, **Actions → Security track CI** should go green: it runs this project's unit and offline test cases.

### 10.4 Mark it complete in your main README

In the **main** `README.md`, change project 14's status to `✅ Complete (torn down to avoid cost)`, then commit and push.

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `TC-14-L03 key admin could read the data!` | The key policy gives the admin role Decrypt | Check `kms.tf`: the admin statement must not include `kms:Decrypt` or `kms:*`; run `terraform -chdir=infrastructure test` |
| `AccessDenied` on `sts:AssumeRole` in the script | Your user can't assume the demo roles | Use your admin user (`aws sts get-caller-identity`) |
| `alias/kms-demo-dev already exists` on deploy | A previous key is still pending deletion with its alias | `aws kms delete-alias --alias-name alias/kms-demo-dev`, then deploy again |
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
