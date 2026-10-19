# Project 04 – VPC from Scratch + Hardened Web Server: Complete Guide

**Tuesday 13 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 3–4 hours. **Estimated cost: about $0.10** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

This project has **no tests and no GitHub Actions workflow**: it's all infrastructure. You push once, at the end.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools and install the Session Manager plugin | No |
| 2 | Add the project files | No |
| 3 | Check your AWS connection | No |
| 4 | Deploy to AWS | **Yes – charges start (~$0.02/hour)** |
| 5 | Show the network | Yes |
| 6 | Show the website and the hardening | Yes |
| 7 | Shell in without SSH | Yes |
| 8 | Logs, metrics and the alarm test | Yes |
| 9 | Tear it all down | Yes |
| 10 | Diagram, push only Project 04, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_4/04-vpc-hardened-web-server/docs/screenshots/` with **exactly** that file name. This project has **13 images** in total.

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

### Install the Session Manager plugin (new for this project)

This lets you open a shell on the server **without SSH**.

**Windows** (PowerShell):

```powershell
winget install --id Amazon.SessionManagerPlugin -e
```

**Mac:**

```bash
brew install --cask session-manager-plugin
```

Close and reopen VS Code, then check:

```bash
session-manager-plugin
```

It should print *"The Session Manager plugin was installed successfully"*.

---
## Part 2 – Add the Project 04 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-04-vpc-web-server.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
├── cloud-pro_3/ ...                         ← yesterday's project
└── cloud-pro_4/04-vpc-hardened-web-server/
    ├── README.md
    ├── infrastructure/                      ← Terraform: network, security, iam, compute, monitoring
    │   └── templates/user_data.sh.tftpl     ← start-up script that installs Nginx + CloudWatch agent
    ├── scripts/                             ← deploy.sh, verify.sh, destroy.sh
    └── docs/                                ← START-HERE, runbook, ADRs, diagram, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_4/04-vpc-hardened-web-server
pwd
```

`pwd` should end with `04-vpc-hardened-web-server`. **Every command from here on runs from this folder** unless it says otherwise.

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

Save (`Ctrl + S`). `.gitignore` keeps this file off GitHub.

### 4.2 Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Wait for `Apply complete! Resources: 26 added` and outputs like:

```
instance_id        = "i-0abc123..."
public_ip          = "54.x.x.x"
vpc_id             = "vpc-0abc..."
web_url            = "http://54.x.x.x"
```

📸 **`01-terraform-apply.png`** – `Apply complete!` and the outputs (blur the IP if you like).

### 4.3 Two things to do straight away

1. **Check your inbox** for *AWS Notification – Subscription Confirmation* and click **Confirm subscription**.
2. **Wait 3–5 minutes.** The server is installing Nginx and the CloudWatch agent in the background.

---

## Part 5 – Show the network

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **VPC** → Your VPCs → `vpc-web-dev-vpc` → **Resource map** tab | The VPC, 4 subnets, 2 route tables and the internet gateway in one picture | `02-vpc-resource-map.png` |
| 📸 | **VPC** → Route tables → `vpc-web-dev-public-rt` → **Routes**, then `vpc-web-dev-private-rt` → **Routes** | Public: `0.0.0.0/0 → igw-…`. Private: only `local`. Put both in one image, or crop and combine two | `03-route-tables.png` |
| 📸 | **EC2** → Security Groups → `vpc-web-dev-web-sg` → **Inbound rules** | Exactly **one** rule: HTTP, TCP 80 | `04-security-group.png` |

**What to say about it in an interview:** a subnet is "public" only because its route table sends `0.0.0.0/0` to the internet gateway. The private route table has no such route.

---

## Part 6 – Show the website and the hardening

Get the address:

```bash
terraform -chdir=infrastructure output -raw web_url
```

Open it in your browser. You should see a page titled **vpc-web-dev** saying *"Port 80 only. No SSH."*

📸 **`05-website.png`** – the page, with the address bar visible.

Now prove the hardening:

```bash
./scripts/verify.sh
```

Expected:

```
== HTTP headers from http://54.x.x.x
HTTP/1.1 200 OK
Server: nginx                 ← no version number = hardened
== Port 22 (should time out or be refused)
Port 22 is closed - no SSH access
```

📸 **`06-verify-script.png`**

If the page doesn't load yet, wait 2 more minutes and try again.

---

## Part 7 – Shell in without SSH

```bash
aws ssm start-session --target "$(terraform -chdir=infrastructure output -raw instance_id)"
```

Or in the console: **EC2 → Instances → `vpc-web-dev-web` → Connect → Session Manager → Connect.**

Inside the session, run these three commands:

```bash
whoami
curl -s -o /dev/null -w '%{http_code}\n' http://169.254.169.254/latest/meta-data/
sudo systemctl status nginx --no-pager | head -5
```

| Command | Expected | What it proves |
|---------|----------|----------------|
| `whoami` | `ssm-user` | You're in without SSH or a key |
| `curl … meta-data` | `401` | IMDSv1 is blocked; only IMDSv2 works |
| `systemctl status nginx` | `active (running)` | The web server is up |

📸 **`07-session-manager.png`** – the session with those three results.

Leave the session open; you'll use it in Part 8. Type `exit` when you're done with it.

### If Session Manager won't connect (rare)

First wait 10 minutes: the agent needs a few minutes to register. If you still get `TargetNotConnected`, check the troubleshooting table at the end. As a last resort, use this SSH fallback:

1. **EC2 → Key pairs → Create key pair**, name `vpc-web-dev-key`, type RSA, format `.pem`. It downloads.
2. Find your IP: `curl https://checkip.amazonaws.com`
3. Add these lines to `infrastructure/terraform.tfvars`:
   ```hcl
   enable_ssh_fallback = true
   ssh_allowed_cidr    = "YOUR.IP.HERE/32"
   ssh_key_name        = "vpc-web-dev-key"
   ```
4. Run `./scripts/deploy.sh` again. This replaces the server, so wait 5 minutes.
5. Connect: `ssh -i ~/Downloads/vpc-web-dev-key.pem ubuntu@$(terraform -chdir=infrastructure output -raw public_ip)`
6. Take `07-session-manager.png` of this SSH session instead, and write in `docs/adr/0001-ssm-instead-of-ssh.md` why Session Manager failed. That's an honest, useful finding.
7. Before the final screenshots of the security group, set `enable_ssh_fallback = false` and deploy again.

---

## Part 8 – Logs, metrics and the alarm test

### 8.1 Nginx logs

Refresh the website 5–10 times so there are log lines, then:

📸 **`08-cloudwatch-logs.png`** – **CloudWatch** → Log groups → `/vpc-web-dev/nginx/access` → the stream named after the instance ID, showing `GET /` lines.

### 8.2 Agent metrics

📸 **`09-agent-metrics.png`** – **CloudWatch** → Metrics → All metrics → **CWAgent** → **InstanceId** → tick `mem_used_percent` and `disk_used_percent`.

These only exist because of the agent: EC2 can't see memory or disk usage on its own. That's a good interview point.

If **CWAgent** isn't listed yet, wait 5 minutes; the agent sends data every minute.

### 8.3 Alarm test (deliberate – label it as a test)

In your Session Manager (or SSH) session:

```bash
sudo apt-get install -y stress-ng
stress-ng --cpu 2 --timeout 300s
```

Watch **CloudWatch → Alarms → `vpc-web-dev-cpu-high`**. It needs 2 minutes above 70%.

**If CPU stays low**, the instance has used up its CPU credits: in Standard credit mode a t3 is held to a low baseline when the balance is empty. Check the `CPUCreditBalance` metric. Then test the alert path directly from VS Code:

```bash
aws cloudwatch set-alarm-state --alarm-name vpc-web-dev-cpu-high \
  --state-value ALARM --state-reason "Deliberate test of the alerting path"
```

📸 **`10-alarm-in-alarm.png`** – the alarm in red **In alarm**, with its graph.
📸 **`11-alarm-email.png`** – the ALARM email. **Blur your email address.**

Write down which way it fired (real CPU or forced) for your Lessons learned. Explaining CPU credits is a strong interview answer.

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

Destroy, never just *stop*, the instance: a stopped instance still pays for its disk and public IP. If you created a key pair for the SSH fallback, delete it too: **EC2 → Key pairs → `vpc-web-dev-key` → Delete**.

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=vpc-web \
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
00-architecture.png       05-website.png            10-alarm-in-alarm.png
01-terraform-apply.png    06-verify-script.png      11-alarm-email.png
02-vpc-resource-map.png   07-session-manager.png    12-terraform-destroy.png
03-route-tables.png       08-cloudwatch-logs.png
04-security-group.png     09-agent-metrics.png
```

### 10.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 10.4 Push only Project 04

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes cloud-pro_4
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "feat(04): VPC with hardened web server, screenshots and docs"
git push
```

### 10.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 04's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 04 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| Page doesn't load | Start-up script still running or failed | Wait 5 min; then in a session: `sudo tail -50 /var/log/cloud-init-output.log` |
| `session-manager-plugin: command not found` | Plugin not installed, or VS Code not restarted | Install it (Part 1) and reopen VS Code |
| `TargetNotConnected` | SSM agent not registered yet, or Session Manager blocked | Wait 5 min; otherwise use the SSH fallback in Part 7 |
| No logs in CloudWatch | Agent config problem | In a session: `sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status` |
| No alarm email | Subscription not confirmed | **SNS → Subscriptions**: status must say **Confirmed** |
| `InvalidParameterCombination` for the instance type | t3.micro not offered in that Availability Zone (rare) | Set `instance_type = "t2.micro"` in `terraform.tfvars` and deploy again |
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
