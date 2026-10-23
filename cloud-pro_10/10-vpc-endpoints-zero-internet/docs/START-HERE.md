# Project 10 – Zero-Internet Workload with VPC Endpoints: Complete Guide

**Wednesday 21 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 2–3 hours. **Estimated cost: about $0.10** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Check your AWS connection | No |
| 4 | Deploy | **Yes – ~$0.035/hour starts** |
| 5 | Show there's no way to the internet | Yes |
| 6 | Show the endpoints and their policies | Yes |
| 7 | Run the five tests on the private server | Yes |
| 8 | Try to read the data from your laptop | Yes |
| 9 | See private DNS at work | Yes |
| 10 | Tear it all down | Yes |
| 11 | Diagram, push only Project 10, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_10/10-vpc-endpoints-zero-internet/docs/screenshots/` with **exactly** that file name. This project has **10 images** in total.

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
## Part 2 – Add the Project 10 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-10-vpc-endpoints.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
└── cloud-pro_10/10-vpc-endpoints-zero-internet/
    ├── README.md
    ├── infrastructure/        ← network (no IGW), endpoints (gateway + interface), data (buckets, table), compute
    ├── scripts/               ← deploy, run_tests, test_from_laptop, destroy
    └── docs/                  ← START-HERE, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_10/10-vpc-endpoints-zero-internet
pwd
```

`pwd` should end with `10-vpc-endpoints-zero-internet`. **Every command from here on runs from this folder** unless it says otherwise.

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

Expected: every `run "…"` line says `pass`, ending with **`Success! 9 passed, 0 failed.`**

Each test has an ID such as `TC-10-T01`; the full list is in [TEST-CASES.md](TEST-CASES.md). If one fails, read its `error_message`: it says which rule is broken.

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

Wait for `Apply complete!` and outputs including `instance_id`, `data_bucket`, `outside_bucket` and `s3_endpoint_id`.

📸 **`01-terraform-apply.png`**

**Wait 3–5 minutes.** The instance's SSM agent registers through the new private endpoints.

---

## Part 5 – Show there's no way to the internet

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **VPC** → Route tables → `private-endpoints-dev-private-rt` → **Routes** | `local`, plus two `pl-…` routes to `vpce-…`. **No `0.0.0.0/0` route** | `02-route-table-no-internet.png` |

Also check **VPC → Internet gateways**: none is attached to `private-endpoints-dev-vpc`.

---

## Part 6 – Show the endpoints and their policies

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **VPC** → **Endpoints** | 5 endpoints: 2 **Gateway** (s3, dynamodb) and 3 **Interface** (ssm, ssmmessages, ec2messages), all **Available** | `03-endpoints.png` |
| 📸 | **VPC** → Endpoints → `private-endpoints-dev-s3-gateway` → **Policy** tab | Allow only on the data bucket ARN | `04-s3-endpoint-policy.png` |
| 📸 | **S3** → `private-endpoints-dev-data-…` → **Permissions** → **Bucket policy** | Deny `s3:GetObject` on `confidential/*` unless `aws:SourceVpce` matches. **Blur the account ID** | `05-bucket-policy.png` |

---

## Part 7 – Run the five tests on the private server

```bash
./scripts/run_tests.sh
```

Expected:

```
== Project 10 live test cases (run on the private server)
  PASS  TC-10-L01 SSM reached the server through the private interface endpoints
  PASS  TC-10-L02 the server can NOT reach the internet
  PASS  TC-10-L03 writes to the data bucket through the S3 gateway endpoint
  PASS  TC-10-L04 reads it back
  PASS  TC-10-L05 a DIFFERENT bucket is blocked by the endpoint policy (AccessDenied)
  PASS  TC-10-L06 writes and reads DynamoDB through its gateway endpoint

Result: 6 passed, 0 failed
```

Test 4 is the key one: the instance's IAM role **does** allow that bucket, so the block proves the **endpoint policy** is working.

📸 **`06-run-tests.png`**

---

## Part 8 – Try to read the data from your laptop (deliberate test)

```bash
./scripts/test_from_laptop.sh
```

Expected: `PASS TC-10-L07 AccessDenied from outside the VPC, even for an administrator`. The error behind it is an **explicit deny in a resource-based policy**. You're an administrator, but the bucket policy only allows reading `confidential/` through the VPC endpoint.

📸 **`07-laptop-denied.png`** – caption it "Deliberate test: admin outside the VPC".

---

## Part 9 – See private DNS at work

Open a session on the private server (it travels over the interface endpoints):

```bash
aws ssm start-session --target "$(terraform -chdir=infrastructure output -raw instance_id)"
```

Then:

```bash
getent hosts ssm.eu-north-1.amazonaws.com
curl -s -m 5 https://example.com || echo "no internet (exit code $?)"
exit
```

Expected: the SSM name resolves to a **10.40.1.x** address (the endpoint's private IP), and the curl times out with exit code 28.

📸 **`08-private-dns.png`**

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

📸 **`09-terraform-destroy.png`**

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=private-endpoints \
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
00-architecture.png               04-s3-endpoint-policy.png   08-private-dns.png
01-terraform-apply.png            05-bucket-policy.png        09-terraform-destroy.png
02-route-table-no-internet.png    06-run-tests.png
03-endpoints.png                  07-laptop-denied.png
```

### 11.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 11.4 Push only Project 10

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes cloud-pro_10
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "feat(10): zero-internet workload with VPC endpoints and policies"
git push
```

### 11.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 10's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 10 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `InvalidInstanceId` from `run_tests.sh` | SSM agent not registered yet | Wait 5 minutes; check the 3 interface endpoints are **Available** |
| `TargetNotConnected` on the session | Same as above | Wait; check the endpoints SG allows 443 from 10.40.0.0/16 |
| Test 2 or 3 fails with AccessDenied | Bucket policy endpoint ID mismatch | Run `./scripts/deploy.sh` again so the policy picks up the current endpoint ID |
| Test 4 says READ SUCCEEDED | Endpoint policy not applied | Check the S3 endpoint's **Policy** tab |
| Laptop test downloads the file | You ran it from inside the VPC, or the bucket policy is missing | Check the bucket policy (Part 6) |
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
