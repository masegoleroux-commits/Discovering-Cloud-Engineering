# Project 07 – AWS Security Baseline: Complete Guide

**Friday 16 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 3 hours, including about 45 minutes of waiting. **Estimated cost: about $0.10–0.50** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

This project has **no tests and no GitHub Actions workflow**. You push once, at the end. AWS Config charges for every change it records, so **destroy the same day**.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Check your AWS connection and existing Config setup | No |
| 4 | Deploy the baseline | **Yes – charges start (small)** |
| 5 | Show CloudTrail | Yes |
| 6 | Show Config rules and the alarms | Yes |
| 7 | Deliberate violations | Yes |
| 8 | Config findings | Yes |
| 9 | Clean up the violations | Yes |
| 10 | Audit an earlier project (optional) | Yes |
| 11 | Tear it all down | Yes |
| 12 | Diagram, push only Project 07, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_7/07-aws-security-baseline/docs/screenshots/` with **exactly** that file name. This project has **12 images** in total.

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
## Part 2 – Add the Project 07 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-07-security-baseline.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
└── cloud-pro_7/07-aws-security-baseline/
    ├── README.md
    ├── infrastructure/                      ← CloudTrail, AWS Config, metric filters, alarms, SNS
    ├── scripts/                             ← deploy, create/cleanup_test_violations, compliance_report, destroy
    └── docs/                                ← START-HERE, runbook, findings.md, ADRs, diagram, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_7/07-aws-security-baseline
pwd
```

`pwd` should end with `07-aws-security-baseline`. **Every command from here on runs from this folder** unless it says otherwise.

---
## Part 3 – Check your AWS connection

### 3.1 Make sure VS Code is signed in as your admin user

```bash
aws sts get-caller-identity
```

The `Arn` must end in `:user/masego-admin` (or whatever you named your admin user). If it ends in `:root`, or you get an error, follow *Part A* in the root `BUILD-GUIDE.md` first.

### 3.2 Check the region in the console

Sign in to the AWS console with your admin user's sign-in URL and check the region in the top right says **Europe (Stockholm) eu-north-1**. Your account only allows this region, and resources in other regions won't appear on screen.

---
### 3.3 Check for an existing Config setup

An account can only have **one** Config recorder per region:

```bash
aws configservice describe-configuration-recorders
```

- `"ConfigurationRecorders": []` → nothing to do.
- A recorder is listed → you'll add `create_config_recorder = false` in Part 4.

Also check which trails already exist:

```bash
aws cloudtrail describe-trails --query 'trailList[].Name'
```

If other trails already exist, only the **first** trail's management events are free; this one would then cost about $2 per 100,000 events. For a few hours that's still cents.

---
## Part 4 – Deploy to AWS

### 4.1 Fill in your settings

```bash
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
```

Open `infrastructure/terraform.tfvars` in VS Code and set:

```hcl
owner       = "masegoleroux-commits"
alert_email = "your-real-email@example.com"
```


Use a real email you can open now. AWS sends a **Confirm subscription** email after the deploy, and alerts only arrive once you click it.

If Part 3.3 found an existing recorder, also add:

```hcl
create_config_recorder = false
```

Save (`Ctrl + S`). `.gitignore` keeps this file off GitHub.

### 4.2 Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Wait for `Apply complete! Resources: 31 added` (fewer if you set `create_config_recorder = false`).

📸 **`01-terraform-apply.png`**

**Confirm the SNS subscription** in your inbox now.

From this point, **don't sign in as root**: the root-usage alarm will fire (that's it working, but it's noise today).

---

## Part 5 – Show CloudTrail

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **CloudTrail** → Trails → `security-baseline-dev-trail` | Status **Logging**, **Multi-region trail: Yes**, **Log file validation: Enabled**, and the CloudWatch Logs log group. **Blur the account ID** | `02-cloudtrail-trail.png` |

Wait **5–10 minutes** for events to arrive, then:

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **CloudWatch** → Log groups → `/security-baseline-dev/cloudtrail` → open a stream → expand one event | `eventName`, `userIdentity` (your admin user) and `sourceIPAddress`. **Blur the account ID and IP** | `03-trail-log-events.png` |

---

## Part 6 – Show Config rules and the alarms

The first evaluations take up to 10 minutes.

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **AWS Config** → **Rules** | The 6 rules with their compliance status | `04-config-rules-before.png` |
| 📸 | **CloudWatch** → **Alarms** → All alarms → search `security-baseline` | The 4 alarms in **OK** or **Insufficient data** | `05-security-alarms.png` |

If any rule is already **Noncompliant**, click it and note the resource: that's a **real finding** in your account. Write it in `docs/findings.md` (it's great interview material).

---

## Part 7 – Deliberate violations (label them as tests)

```bash
./scripts/create_test_violations.sh
```

It takes 2–3 minutes and creates:

| Test resource | Should trigger |
|---------------|----------------|
| Security group open to SSH from `0.0.0.0/0` | `restricted-ssh` rule + **security-group-changes** alarm |
| t3.nano instance that still allows IMDSv1 | `ec2-imdsv2-check` rule |
| Unencrypted 1 GB volume attached to it | `encrypted-volumes` rule |
| A temporary role with **no permissions**, used to make one API call | **unauthorized-api-calls** alarm |

📸 **`06-test-violations.png`** – the script output. Caption it "Deliberate test".

Within **5–10 minutes** the security-group-changes alarm should go to **In alarm** and email you.

📸 **`07-sg-change-alarm.png`** – the alarm in **In alarm**, or the email (**blur your address**).

The **unauthorized-api-calls** alarm should fire as well, from the denied `DescribeInstances` call.

---

## Part 8 – Config findings

Wait **10–15 minutes** after Part 7. Then **AWS Config → Rules** → click `restricted-ssh`, `ec2-imdsv2-check` and `encrypted-volumes`. Each should list the test resource as **Noncompliant**.

📸 **`08-config-noncompliant.png`**

Then in VS Code:

```bash
./scripts/compliance_report.sh
```

📸 **`09-compliance-report.png`**

**If `encrypted-volumes` stays compliant:** your account probably has **EBS encryption by default** turned on (EC2 → Dashboard → **Account attributes** → **Data protection and security**). Then the volume was encrypted anyway. Write that in `docs/findings.md`: the account-level setting made the violation impossible, which is the best kind of control.

---

## Part 9 – Clean up the violations

```bash
./scripts/cleanup_test_violations.sh
```

This terminates the test instance (about 1 minute) and deletes the volume, security group and test role.

After **10–15 minutes**, Config re-evaluates and the rules return to **Compliant**, or the deleted resources drop off the list.

📸 **`10-config-after-cleanup.png`**

---

## Part 10 – Audit an earlier project (optional)

With the baseline still running, deploy one earlier project (for example project 04), wait 15 minutes, and check the Config rules. Write every result in `docs/findings.md`, including "no findings" if that's what happened. Then destroy that project again.

### Screenshot rules

- Windows: `Win + Shift + S` · Mac: `Cmd + Shift + 4`
- Save as **PNG**, cropped to the useful part.
- **Blur** the 12-digit account ID, your email, public IPs (optional) and any access keys. Never screenshot the `aws configure` answers or the access key CSV.
- Label deliberate tests and synthetic data in your README captions.

---

## Part 11 – Tear it all down (same day)

```bash
./scripts/destroy.sh
```

Wait for `Destroy complete!`

📸 **`11-terraform-destroy.png`**

This deletes the trail, Config, the alarms and both log buckets (with the logs in them). In a real company you would keep CloudTrail logs, often for years; deleting them here is only to stop charges on a practice project.

**Double-check the test resources are gone too** (they were created by script, not Terraform):

```bash
aws ec2 describe-instances --filters Name=tag:Purpose,Values=security-baseline-deliberate-test \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output table
```

Every instance listed should be `terminated`.

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=security-baseline \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

An empty table means you're clean. Deleted items can linger in this list for a few minutes; if something is still there after an hour, run `./scripts/destroy.sh` again.

---
## Part 12 – Diagram, final push, mark complete

### 12.1 Architecture image

In VS Code, open `docs/architecture.drawio` (the Draw.io extension shows the diagram), export it as **PNG**, and save it as:

📸 **`docs/screenshots/00-architecture.png`**

(Or open the file at https://app.diagrams.net → **File → Export as → PNG**.)

### 12.2 Check you have every image

```bash
ls docs/screenshots/
```

You should see:

```
00-architecture.png          04-config-rules-before.png   08-config-noncompliant.png
01-terraform-apply.png       05-security-alarms.png       09-compliance-report.png
02-cloudtrail-trail.png      06-test-violations.png       10-config-after-cleanup.png
03-trail-log-events.png      07-sg-change-alarm.png       11-terraform-destroy.png
```

### 12.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

Also fill in `docs/findings.md` with what actually happened in Parts 6–10.

### 12.4 Push only Project 07

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes cloud-pro_7
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "feat(07): AWS security baseline, findings and screenshots"
git push
```

### 12.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 07's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 07 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `MaxNumberOfConfigurationRecordersExceeded` | A recorder already exists | Set `create_config_recorder = false` and deploy again |
| `InsufficientS3BucketPolicyException` | The trail's bucket policy didn't apply first | Run `./scripts/deploy.sh` again |
| `NoSuchConfigurationRecorderException` on the rules | You set `create_config_recorder = false` but no recorder exists | Remove that line from `terraform.tfvars` |
| Rules stuck on "No results" | Recorder not recording yet | **AWS Config → Settings**: recording must be **On**; wait 10 minutes |
| Metric filter alarm never fires | Events take 5–15 minutes to reach CloudWatch Logs | Wait; on the log group, use **Metric filters → Test pattern** |
| `create_test_violations.sh` fails on `assume-role` | The new role hadn't spread through IAM yet | Run `./scripts/cleanup_test_violations.sh`, then the create script again |
| `.test-violations.env: No such file` during cleanup | The create script stopped early | Delete leftovers by hand: EC2 → instances/volumes/security groups tagged `Purpose = security-baseline-deliberate-test`, and IAM role `security-baseline-test-no-permissions` |
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
