# Project 09 – Private Subnets with a NAT Instance and VPC Flow Logs: Complete Guide

**Tuesday 20 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 2–3 hours. **Estimated cost: about $0.07** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools | No |
| 2 | Add the project files | No |
| 3 | Check your AWS connection | No |
| 4 | Deploy | **Yes – ~$0.015/hour starts** |
| 5 | Show how the NAT is wired | Yes |
| 6 | Prove the private server goes out through the NAT | Yes |
| 7 | Look inside the NAT | Yes |
| 8 | Search the Flow Logs | Yes |
| 9 | Show the self-healing alarm | Yes |
| 10 | Tear it all down | Yes |
| 11 | Diagram, push only Project 09, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_9/09-nat-instance-flow-logs/docs/screenshots/` with **exactly** that file name. This project has **11 images** in total.

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
## Part 2 – Add the Project 09 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-09-nat-flow-logs.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
└── cloud-pro_9/09-nat-instance-flow-logs/
    ├── README.md
    ├── infrastructure/        ← network, security, compute (NAT + app), monitoring (flow logs, queries, alarm)
    │   └── templates/nat_user_data.sh.tftpl   ← turns the instance into a router
    ├── scripts/               ← deploy, test_egress, test_rejected, destroy
    └── docs/                  ← START-HERE, runbook, ADRs, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_9/09-nat-instance-flow-logs
pwd
```

`pwd` should end with `09-nat-instance-flow-logs`. **Every command from here on runs from this folder** unless it says otherwise.

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

Each test has an ID such as `TC-09-T01`; the full list is in [TEST-CASES.md](TEST-CASES.md). If one fails, read its `error_message`: it says which rule is broken.

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

Wait for `Apply complete!` and outputs including `nat_public_ip`, `app_instance_id` and `flow_log_group`.

📸 **`01-terraform-apply.png`**

Then:
1. **Confirm the SNS subscription** in your inbox.
2. **Wait 3–5 minutes.** The NAT instance configures itself first; only then can the private app server reach SSM and register.

---

## Part 5 – Show how the NAT is wired

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **EC2** → Instances → `nat-egress-dev-nat` → **Networking** tab | **Source / destination check: false** (or *Stopped*), plus the Elastic IP | `02-nat-source-dest-check.png` |
| 📸 | **VPC** → Route tables → `nat-egress-dev-private-rt` → **Routes** | `0.0.0.0/0 → eni-…` (the NAT's network interface) and `local` | `03-private-route-table.png` |

---

## Part 6 – Prove the private server goes out through the NAT

```bash
./scripts/test_egress.sh
```

Expected:

```
== Project 09 live test cases: egress
  PASS  TC-09-L01 app server has no public IP
  PASS  TC-09-L02 NAT source/destination check is off
  PASS  TC-09-L03 SSM reached the private server (it registered through the NAT)
  PASS  TC-09-L04 internet sees the NAT Elastic IP (54.x.x.x)
  PASS  TC-09-L05 HTTPS from the private server works (200)

Result: 5 passed, 0 failed
```

The server has no public IP, yet the internet sees the NAT's Elastic IP. That's NAT working. If you get `InvalidInstanceId`, the app's SSM agent hasn't registered yet: wait 2 minutes and try again.

📸 **`04-egress-test.png`** – blur the public IP if you like, but show that the two match.

---

## Part 7 – Look inside the NAT

Open a session on the NAT instance:

```bash
aws ssm start-session --target "$(terraform -chdir=infrastructure output -raw nat_instance_id)"
```

Then run:

```bash
sysctl net.ipv4.ip_forward
sudo iptables -t nat -L POSTROUTING -n -v
sudo iptables -L FORWARD -n -v
exit
```

| Command | Expected | Meaning |
|---------|----------|---------|
| `sysctl` | `net.ipv4.ip_forward = 1` | The kernel forwards packets |
| `-t nat … POSTROUTING` | A `MASQUERADE` rule for `10.30.11.0/24` with **packet counts above 0** | Translation is happening |
| `FORWARD` | ACCEPT rules with packet counts, then DROP | Only the private subnet is forwarded |

📸 **`05-nat-iptables.png`**

---

## Part 8 – Search the Flow Logs

### 8.1 Raw records

**CloudWatch** → Log groups → `/nat-egress-dev/vpc-flow-logs` → open a stream (one per network interface).

📸 **`06-flow-log-records.png`** – a few lines. Each line is: version, account, interface, source, destination, ports, protocol, packets, bytes, start, end, **ACCEPT/REJECT**, status. Blur the account ID.

### 8.2 Rejected traffic (deliberate test)

```bash
./scripts/test_rejected.sh
```

It tries ports 22, 3389 and 8080 on the NAT's public IP (`PASS TC-09-L06` to `L08`: all blocked), then waits up to 10 minutes for Flow Logs to record the port-22 attempt as `REJECT` (`TC-09-L09`). Wait 2 minutes, then:

**CloudWatch** → **Logs Insights** → **Saved queries** (or the **Queries** panel on the right) → `nat-egress-dev/rejected-traffic` → **Run query**.

📸 **`07-rejected-query.png`** – your IP with the rejected ports. Caption it "Deliberate test", and blur your IP.

You'll probably also see rejected attempts from addresses that aren't yours. That's the internet's background scanning, which hits every public IP within minutes. Mention it in your Lessons learned: it's real evidence of why closed ports matter.

### 8.3 The app server's outbound connections

Run `./scripts/test_egress.sh` once more, wait 2 minutes, then run the saved query `nat-egress-dev/app-egress-via-nat`.

📸 **`08-app-egress-query.png`** – connections from the app's private IP on port 443.

---

## Part 9 – Show the self-healing alarm

**CloudWatch** → **Alarms** → `nat-egress-dev-nat-system-check-failed` → **Details** / **Actions**.

📸 **`09-nat-recovery-alarm.png`** – the two actions: **Recover this instance** and the SNS topic.

Don't try to trigger it: AWS only fails system checks on real hardware problems. What it does: it moves the instance to healthy hardware while keeping its ID, private IP and Elastic IP.

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
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=nat-egress \
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
00-architecture.png             04-egress-test.png         08-app-egress-query.png
01-terraform-apply.png          05-nat-iptables.png        09-nat-recovery-alarm.png
02-nat-source-dest-check.png    06-flow-log-records.png    10-terraform-destroy.png
03-private-route-table.png      07-rejected-query.png
```

### 11.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 11.4 Push only Project 09

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes cloud-pro_9
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "feat(09): NAT instance egress with VPC Flow Logs"
git push
```

### 11.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 09's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 09 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `InvalidInstanceId` from `test_egress.sh` | App's SSM agent hasn't registered (it needs the NAT first) | Wait 5 minutes; check the NAT is running and the private route exists |
| `Seen by the internet as:` is empty | NAT isn't forwarding | Part 7: check `ip_forward` and the iptables rules; read `/var/log/cloud-init-output.log` on the NAT |
| `TargetNotConnected` on the NAT session | NAT's SSM agent not registered yet | Wait 3 minutes |
| No Flow Log streams | First batch takes 1–5 minutes | Wait |
| Saved query isn't listed | Different region selected in the console | Switch to Europe (Stockholm) eu-north-1 |
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
