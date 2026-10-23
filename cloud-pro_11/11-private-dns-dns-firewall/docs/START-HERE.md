# Project 11 – Private DNS and Route 53 Resolver DNS Firewall: Complete Guide

**Thursday 22 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 2 hours. **Estimated cost: about $0.05** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Check your AWS connection | No |
| 4 | Deploy | **Yes – ~$0.01/hour starts** |
| 5 | Show the private zone and the firewall rules | Yes |
| 6 | Ask DNS questions from inside the VPC | Yes |
| 7 | Prove private names don't leak | Yes |
| 8 | Search the query logs | Yes |
| 9 | Tear it all down | Yes |
| 10 | Diagram, push only Project 11, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_11/11-private-dns-dns-firewall/docs/screenshots/` with **exactly** that file name. This project has **9 images** in total.

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
## Part 2 – Add the Project 11 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-11-private-dns.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
└── cloud-pro_11/11-private-dns-dns-firewall/
    ├── README.md
    ├── infrastructure/        ← network, dns (zone, records, firewall, query logs), compute (client)
    ├── scripts/               ← deploy, test_dns, test_from_laptop, destroy
    └── docs/                  ← START-HERE, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_11/11-private-dns-dns-firewall
pwd
```

`pwd` should end with `11-private-dns-dns-firewall`. **Every command from here on runs from this folder** unless it says otherwise.

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
## Before you deploy – run the offline test cases (free)

These 7 test cases check the security and routing rules in the Terraform code against a **mocked** AWS. They need no AWS account and cost nothing, so a mistake is caught before you pay for anything.

```bash
terraform -chdir=infrastructure init
terraform -chdir=infrastructure test
```

Expected: every `run "…"` line says `pass`, ending with **`Success! 7 passed, 0 failed.`**

Each test has an ID such as `TC-11-T01`; the full list is in [TEST-CASES.md](TEST-CASES.md). If one fails, read its `error_message`: it says which rule is broken.

---

## Part 4 – Deploy to AWS

### 4.1 Fill in your settings

```bash
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
```

Open `infrastructure/terraform.tfvars` in VS Code and set:

```hcl
owner       = "masegoleroux-commits"
```


Save (`Ctrl + S`). `.gitignore` keeps this file off GitHub.

### 4.2 Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Wait for `Apply complete!` and outputs including `private_zone = "corp.internal"`, `service_ips` and `client_instance_id`.

📸 **`01-terraform-apply.png`**

**Wait about 3 minutes** for the client to install `dig` and register with SSM. **Don't delete and recreate the hosted zone repeatedly**: zones kept longer than 12 hours cost $0.50.

---

## Part 5 – Show the private zone and the firewall rules

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **Route 53** → Hosted zones → `corp.internal` | Type **Private**, the VPC it's associated with, and the records: `app`, `db` (A), `api` (CNAME), `sinkhole` (A), `_owner` (TXT) | `02-private-zone-records.png` |
| 📸 | **VPC** → **DNS firewall rule groups** (under *DNS Firewall*) → `private-dns-dev-rules` → **Rules** tab | Three rules: priority 100 BLOCK (NXDOMAIN), 200 BLOCK (OVERRIDE), 300 ALERT | `03-firewall-rules.png` |

---

## Part 6 – Ask DNS questions from inside the VPC

```bash
./scripts/test_dns.sh
```

Expected:

```
== Project 11 live test cases (DNS questions asked inside the VPC)
  PASS  TC-11-L01 app.corp.internal resolves to a private IP (10.50.x.x)
  PASS  TC-11-L02 api.corp.internal CNAME resolves (app.corp.internal.)
  PASS  TC-11-L03 public names still resolve (aws.amazon.com -> x.x.x.x)
  PASS  TC-11-L04 doubleclick.net is BLOCKED (NXDOMAIN)
  PASS  TC-11-L05 example.org is SINKHOLED to 192.0.2.1
  PASS  TC-11-L06 example.net is ALLOWED but flagged (alert rule) -> x.x.x.x

Result: 6 passed, 0 failed
```

| Line | What it proves |
|------|----------------|
| 1–2 | The private zone works, including a CNAME chain |
| 3 | Normal internet names still resolve |
| 4 | The block rule answers "doesn't exist" |
| 5 | The sinkhole rule redirects to a safe internal address |
| 6 | The alert rule allows the lookup (it gets flagged in the logs) |

📸 **`04-dns-tests.png`**

If line 4 still shows an IP, the firewall association needs another minute: wait and run it again.

---

## Part 7 – Prove private names don't leak

```bash
./scripts/test_from_laptop.sh
```

Expected: `** server can't find app.corp.internal: NXDOMAIN` (or similar), then `PASS TC-11-L07`. The name only exists inside the VPC.

📸 **`05-laptop-cannot-resolve.png`**

---

## Part 8 – Search the query logs

Wait 2–3 minutes after Part 6, then **CloudWatch** → **Logs Insights** → **Queries** panel → saved queries:

| # | Query | What must be visible | Save as |
|---|-------|----------------------|---------|
| 📸 | `private-dns-dev/firewall-hits` | Rows for `doubleclick.net` and `example.org` with action **BLOCK**, and `example.net` with **ALERT** | `06-query-log-firewall-hits.png` |
| 📸 | `private-dns-dev/top-queried-names` | The names your client looked up, plus background ones (SSM, package repositories) | `07-top-queried-names.png` |

The background lookups in the second query are worth noticing: even an idle server constantly asks DNS questions, which is why query logs are so useful in investigations.

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
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=private-dns \
  --query 'ResourceTagMappingList[].ResourceARN' --output table
```

An empty table means you're clean. Deleted items can linger in this list for a few minutes; if something is still there after an hour, run `./scripts/destroy.sh` again.

---
## Part 10 – Diagram, final push, mark complete

### 10.1 Architecture image

In VS Code, open `docs/architecture.drawio` (the Draw.io extension shows the diagram), export it as **PNG**, and save it as:

📸 **`docs/screenshots/00-architecture.png`**

(Or open the file at https://app.diagrams.net → **File → Export as → PNG**.)

### 10.2 Check you have every image

```bash
ls docs/screenshots/
```

You should see:

```
00-architecture.png           03-firewall-rules.png            06-query-log-firewall-hits.png
01-terraform-apply.png        04-dns-tests.png                 07-top-queried-names.png
02-private-zone-records.png   05-laptop-cannot-resolve.png     08-terraform-destroy.png
```

### 10.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 10.4 Push only Project 11

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes cloud-pro_11
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "feat(11): private DNS with Route 53 Resolver DNS Firewall"
git push
```

### 10.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 11's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 11 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `dig: command not found` in the output | Start-up script still installing bind-utils | Wait 2 minutes and run `./scripts/test_dns.sh` again |
| `InvalidInstanceId` | SSM agent not registered yet | Wait 3 minutes |
| `doubleclick.net` still resolves | Firewall association not active yet | Wait 1–2 minutes; **VPC → DNS firewall rule groups → Associated VPCs** must say **Complete** |
| Line 5 shows example.org's real address | Same as above | Wait and retry |
| Query log group is empty | Logging takes a few minutes to start | Run the tests again after 5 minutes |
| `CreateResolverQueryLogConfig` AccessDenied on the log group | Missing permission to create the log delivery | You must be an admin user; run `./scripts/deploy.sh` again |
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
