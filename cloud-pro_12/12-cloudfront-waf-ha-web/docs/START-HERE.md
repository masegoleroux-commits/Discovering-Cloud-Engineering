# Project 12 – Highly Available Web Tier behind CloudFront and AWS WAF: Complete Guide

**Friday 23 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 3 hours, including about 30 minutes of waiting for CloudFront. **Estimated cost: about $0.25** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Check your AWS connection | No |
| 4 | Deploy | **Yes – ~$0.06/hour starts** |
| 5 | Visit the site and test access | Yes |
| 6 | Show how the origin is locked down | Yes |
| 7 | Show the WAF and test the rate limit | Yes |
| 8 | Prove it heals itself | Yes |
| 9 | Tear it all down | Yes |
| 10 | Diagram, push only Project 12, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_12/12-cloudfront-waf-ha-web/docs/screenshots/` with **exactly** that file name. This project has **13 images** in total.

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
## Part 2 – Add the Project 12 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-12-cloudfront-waf.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
└── cloud-pro_12/12-cloudfront-waf-ha-web/
    ├── README.md
    ├── infrastructure/        ← network (VPC, SGs, S3 endpoint), alb, compute (launch template, ASG), edge (WAF, CloudFront)
    │   └── templates/web_user_data.sh   ← installs Nginx and the whoami page
    ├── scripts/               ← deploy, test_access, test_rate_limit, test_self_healing, destroy
    └── docs/                  ← START-HERE, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_12/12-cloudfront-waf-ha-web
pwd
```

`pwd` should end with `12-cloudfront-waf-ha-web`. **Every command from here on runs from this folder** unless it says otherwise.

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

These 9 test cases check the security and routing rules in the Terraform code against a **mocked** AWS. They need no AWS account and cost nothing, so a mistake is caught before you pay for anything.

```bash
terraform -chdir=infrastructure init
terraform -chdir=infrastructure test
```

Expected: every `run "…"` line says `pass`, ending with **`Success! 10 passed, 0 failed.`**

Each test has an ID such as `TC-12-T01`; the full list is in [TEST-CASES.md](TEST-CASES.md). If one fails, read its `error_message`: it says which rule is broken.

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

This takes **10–15 minutes**, mostly waiting for CloudFront to spread to its edge locations. Wait for `Apply complete!` and outputs `site_url`, `alb_url`, `asg_name` and `web_acl_name`.

📸 **`01-terraform-apply.png`**

Give the servers another **3–5 minutes** to install Nginx and pass their health checks. Until then CloudFront may return a 502 or 504.

---

## Part 5 – Visit the site and test access

Open the `site_url` (`https://dxxxx.cloudfront.net`) in your browser. Refresh a few times: the instance ID and Availability Zone should change between your two servers.

📸 **`02-site-in-browser.png`** – with the padlock and address bar visible.

```bash
./scripts/test_access.sh
```

Expected:

```
== Project 12 live test cases: access (https://dxxxxxxxx.cloudfront.net)
  PASS  TC-12-L01 site answers 200 through the front door
        zones seen: "az":"eu-north-1a" "az":"eu-north-1b"
  PASS  TC-12-L02 two Availability Zones answered
  PASS  TC-12-L03 visitors use HTTPS (CloudFront)
  PASS  TC-12-L04 direct access to the load balancer gets no answer (security group allows only CloudFront)

Result: 4 passed, 0 failed
```

📸 **`03-test-access.png`**

---

## Part 6 – Show how the origin is locked down

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **EC2** → Security Groups → `edge-web-dev-alb-sg` → **Inbound rules** | One rule: HTTP 80 from `pl-…` (the CloudFront origin-facing prefix list) | `04-alb-security-group.png` |
| 📸 | **EC2** → Load Balancers → `edge-web-dev-alb` → **Listeners and rules** → HTTP:80 | Rule 1: *HTTP header X-Origin-Verify is …* → forward. Default: fixed **403**. Blur the header value | `05-alb-listener-rules.png` |
| 📸 | **EC2** → Target groups → `edge-web-dev-tg` → **Targets** | 2 targets, **healthy**, in 2 different AZs | `06-target-group-healthy.png` |

---

## Part 7 – Show the WAF and test the rate limit

**WAF & Shield** → **Web ACLs** → set the region selector to **Europe (Stockholm)** → `edge-web-dev-waf` → **Rules** tab. (If you changed `waf_scope` to `CLOUDFRONT`, choose **Global (CloudFront)** instead.)

The **Associated AWS resources** tab shows it's attached to `edge-web-dev-alb`.

📸 **`07-waf-rules.png`** – the three rules: `rate-limit-per-ip` (priority 1), `aws-common-rules`, `aws-known-bad-inputs`.

Now the deliberate test:

```bash
./scripts/test_rate_limit.sh
```

It sends 300 requests over about 2 minutes. WAF needs up to a minute to notice, so expect something like:

```
== Project 12 live test case: rate limit (deliberate test) on https://dxxxxxxxx.cloudfront.net/health
        round 1 (50 requests): 50 allowed, 0 blocked by WAF
        round 2 (50 requests): 50 allowed, 0 blocked by WAF
        round 3 (50 requests): 12 allowed, 38 blocked by WAF
        round 4 (50 requests): 0 allowed, 50 blocked by WAF
        ...
  PASS  TC-12-L05 WAF rate limit blocked 188 requests
```

📸 **`08-rate-limit-test.png`** – caption it "Deliberate test".

Then back in the web ACL → **Overview** (or **Sampled requests**) → filter by rule `rate-limit-per-ip`.

📸 **`09-waf-blocked-requests.png`** – the blocked requests with action **BLOCK**. Blur your IP.

Your IP stays blocked for a minute or two after the test. Wait before Part 8, or the site checks will show 403 instead of 200.

---

## Part 8 – Prove it heals itself (deliberate test)

```bash
./scripts/test_self_healing.sh
```

It terminates one server and then, every 10 seconds for 5 minutes, prints the site's status and the servers in the group. Expected: **`site: 200` every time**, and the count of servers in service climbs back to the desired number. It ends with `PASS TC-12-L06` (zero failed requests) and `PASS TC-12-L07` (server replaced).

📸 **`10-self-healing.png`**

**EC2** → **Auto Scaling groups** → `edge-web-dev-asg` → **Activity** tab.

📸 **`11-asg-activity.png`** – the termination and the replacement launch.

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

📸 **`12-terraform-destroy.png`**

This takes **10–15 minutes**: CloudFront has to be disabled everywhere before it can be deleted, and the WAF web ACL can only go after that. Let it finish.

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=edge-web \
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
00-architecture.png         05-alb-listener-rules.png     10-self-healing.png
01-terraform-apply.png      06-target-group-healthy.png   11-asg-activity.png
02-site-in-browser.png      07-waf-rules.png              12-terraform-destroy.png
03-test-access.png          08-rate-limit-test.png
04-alb-security-group.png   09-waf-blocked-requests.png
```

### 10.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 10.4 Push only Project 12

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes cloud-pro_12
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "feat(12): HA web tier behind CloudFront and AWS WAF"
git push
```

### 10.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 12's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 12 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| CloudFront returns 502 or 504 | No healthy servers yet | Wait 3–5 minutes after apply; check Part 6's target group |
| Targets keep failing health checks | Nginx didn't install | EC2 → Instances → a web server → **Actions → Monitor and troubleshoot → Get system log**; look for `dnf` errors |
| "Direct access is not allowed" through CloudFront | Header secret mismatch | Run `./scripts/deploy.sh` again |
| Every request returns 403 | Your IP is still rate-limited from Part 7 | Wait 2 minutes |
| `WAFUnavailableEntityException` on apply | The web ACL wasn't ready when CloudFront was created | Run `./scripts/deploy.sh` again |
| `destroy` fails on the web ACL | CloudFront still being deleted | Wait 5 minutes and run `./scripts/destroy.sh` again |
| The web ACL isn't listed in the console | Wrong region selected | Choose **Europe (Stockholm)** (or **Global** if `waf_scope = "CLOUDFRONT"`) |
| `explicit deny in a service control policy` on `cloudfront:*` | Your account blocks CloudFront | Add `enable_cloudfront = false` to `terraform.tfvars` and deploy again. The ALB becomes the public entry, still behind the regional WAF |
| `explicit deny` on `wafv2` in us-east-1 | `waf_scope = "CLOUDFRONT"` needs us-east-1 | Use the default `waf_scope = "REGIONAL"` |
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
