# Project 08 – Hub-and-Spoke Network with Transit Gateway: Complete Guide

**Monday 19 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 2–3 hours. **Estimated cost: about $0.90** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Check your AWS connection | No |
| 4 | Deploy | **Yes – ~$0.15/hour starts** |
| 5 | Show the hub and its route tables | Yes |
| 6 | Prove the segmentation | Yes (~$0.30) |
| 7 | Show a reachable and a blocked path | Yes |
| 8 | Flip the segmentation switch | Yes (~$0.30) |
| 9 | Tear it all down | Yes |
| 10 | Diagram, push only Project 08, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_8/08-transit-gateway-hub-spoke/docs/screenshots/` with **exactly** that file name. This project has **10 images** in total.

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
## Part 2 – Add the Project 08 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-08-transit-gateway.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
└── cloud-pro_8/08-transit-gateway-hub-spoke/
    ├── README.md
    ├── infrastructure/        ← network.tf (3 VPCs), tgw.tf (hub + route tables), probes.tf (ENIs + test paths)
    ├── scripts/               ← deploy.sh, run_analysis.sh, destroy.sh
    └── docs/                  ← START-HERE, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_8/08-transit-gateway-hub-spoke
pwd
```

`pwd` should end with `08-transit-gateway-hub-spoke`. **Every command from here on runs from this folder** unless it says otherwise.

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

These 8 test cases check the security and routing rules in the Terraform code against a **mocked** AWS. They need no AWS account and cost nothing, so a mistake is caught before you pay for anything.

```bash
terraform -chdir=infrastructure init
terraform -chdir=infrastructure test
```

Expected: every `run "…"` line says `pass`, ending with **`Success! 8 passed, 0 failed.`**

Each test has an ID such as `TC-08-T01`; the full list is in [TEST-CASES.md](TEST-CASES.md). If one fails, read its `error_message`: it says which rule is broken.

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

It takes 3–5 minutes (Transit Gateway attachments are slow to create). Wait for `Apply complete!` and outputs including `transit_gateway_id`, `tgw_route_tables` and three `path_…` IDs.

📸 **`01-terraform-apply.png`**

---

## Part 5 – Show the hub and its route tables

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **VPC** → **Transit gateway attachments** | 3 attachments (`shared`, `app`, `data`), all **Available** | `02-tgw-attachments.png` |
| 📸 | **VPC** → **Transit gateway route tables** → `tgw-hub-dev-spokes-rt` → **Associations** tab, then **Propagations** tab | Associated: app and data. Propagations: **only shared** | `03-tgw-route-tables.png` |
| 📸 | **VPC** → **Route tables** → `tgw-hub-dev-app-rt` → **Routes** | `10.100.0.0/16` and `10.102.0.0/16` → `tgw-…`, plus `local` | `04-vpc-route-table.png` |

Notice the trap in screenshot 04: the app VPC *does* send data-VPC traffic to the hub. The block happens **inside** the Transit Gateway, because `spokes-rt` has no route back out to data.

---

## Part 6 – Prove the segmentation

```bash
./scripts/run_analysis.sh
```

Expected (takes about 1–2 minutes, costs about $0.30):

```
== Project 08 live test cases (allow_app_to_data = false)
                PATH             REACHABLE  EXPECTED  FIRST EXPLANATION (if blocked)
  PASS TC-08-L01 app-to-shared    True       True      -
  PASS TC-08-L02 data-to-shared   True       True      -
  PASS TC-08-L03 app-to-data      False      False     TGW_RTB_CANNOT_ROUTE

Result: 3 passed, 0 failed
```

The exact explanation code may be worded differently; what matters is `False` for app-to-data.

📸 **`05-analysis-results.png`**

---

## Part 7 – Show a reachable and a blocked path

**VPC** → **Reachability Analyzer** (left menu, under *Network Analysis*) → you'll see the 3 paths.

| # | Open | What must be visible | Save as |
|---|------|----------------------|---------|
| 📸 | `tgw-hub-dev-app-to-shared` → latest analysis | **Reachable**, with the hop-by-hop path: ENI → route table → TGW attachment → TGW route table → shared attachment → ENI | `06-path-reachable.png` |
| 📸 | `tgw-hub-dev-app-to-data` → latest analysis | **Not reachable**, with the explanation pointing at the TGW route table | `07-path-blocked.png` |

---

## Part 8 – Flip the segmentation switch

Open `infrastructure/terraform.tfvars` and add:

```hcl
allow_app_to_data = true
```

Then:

```bash
./scripts/deploy.sh          # adds 2 propagations into spokes-rt
./scripts/run_analysis.sh    # app-to-data should now be True
```

📸 **`08-segmentation-change.png`** – the terminal showing `allow_app_to_data = true` and `app-to-data True`. Ideally include the `terraform apply` lines that added the 2 propagations.

**Put it back** (`allow_app_to_data = false`) and run `./scripts/deploy.sh` again. You don't need to re-run the analysis.

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

📸 **`09-terraform-destroy.png`**

Transit Gateway attachments take a few minutes each to delete. Let it finish.

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=tgw-hub \
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
00-architecture.png      04-vpc-route-table.png     08-segmentation-change.png
01-terraform-apply.png   05-analysis-results.png    09-terraform-destroy.png
02-tgw-attachments.png   06-path-reachable.png
03-tgw-route-tables.png  07-path-blocked.png
```

### 10.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 10.4 Push only Project 08

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes cloud-pro_8
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "feat(08): Transit Gateway hub-and-spoke with segmentation proofs"
git push
```

### 10.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 08's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 08 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| Attachment stays `pending` | Normal for a few minutes | Wait, then run `./scripts/deploy.sh` again if it timed out |
| `app-to-shared False` | Missing propagation into `spokes-rt` | Check `tgw.tf`; run `./scripts/deploy.sh` again |
| Script prints `None` for REACHABLE | The analysis was still running after 2.5 minutes | Run `./scripts/run_analysis.sh` again |
| `explicit deny in a service control policy` | Something tried a region other than eu-north-1 | Check `aws configure get region` says `eu-north-1` |
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
