# 04 – VPC from Scratch + Hardened Web Server

A hand-written two-Availability-Zone VPC with one Ubuntu web server that is reachable only on port 80 and administered only through AWS Systems Manager Session Manager: no SSH port, no key pair. Nginx logs and memory/disk metrics go to CloudWatch, and alarms email me.

![Architecture](docs/screenshots/00-architecture.png)

## The problem

Many breaches start with an exposed SSH port or a forgotten admin key. This project shows a web server whose only open port is the one users need, inside a network I built and can explain line by line.

## Tech stack

`Amazon VPC` · `EC2` · `Internet Gateway` · `Security Groups` · `IAM` · `SSM Session Manager` · `CloudWatch Logs, Metrics & Alarms` · `SNS` · `Terraform` · `Ubuntu 24.04` · `Nginx` · `Bash`

## Network layout

| Subnet | CIDR | Availability Zone | Route to internet |
|--------|------|-------------------|-------------------|
| `vpc-web-dev-public-a` | `10.20.1.0/24` | 1st | Yes, via internet gateway |
| `vpc-web-dev-public-b` | `10.20.2.0/24` | 2nd | Yes, via internet gateway |
| `vpc-web-dev-private-a` | `10.20.11.0/24` | 1st | No |
| `vpc-web-dev-private-b` | `10.20.12.0/24` | 2nd | No |

The private subnets are reserved for a future data tier. They have no outbound route because a NAT gateway costs about $32 a month even when idle (see ADR 0003).

## Quickstart

```bash
cd cloud-pro_4/04-vpc-hardened-web-server
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars   # set owner and alert_email
./scripts/deploy.sh
./scripts/verify.sh
./scripts/destroy.sh
```

Step-by-step guide: [docs/START-HERE.md](docs/START-HERE.md). Short operations card: [docs/runbook.md](docs/runbook.md).

## Key design decisions

- [0001 – Session Manager instead of SSH](docs/adr/0001-ssm-instead-of-ssh.md)
- [0002 – Ubuntu 24.04 LTS](docs/adr/0002-ubuntu-2404.md)
- [0003 – No NAT gateway](docs/adr/0003-no-nat-gateway.md)
- [0004 – Web server in a public subnet, no load balancer](docs/adr/0004-public-subnet-server.md)

## Security and observability

- **Only port 80 is open.** No SSH rule exists unless the documented fallback is switched on.
- **IMDSv2 required**, which blocks a common way of stealing instance credentials.
- **Encrypted root disk**, and the Nginx version is hidden from response headers.
- **CloudWatch:** Nginx access and error logs, memory and disk metrics, a CPU alarm and a status-check alarm, both emailing via SNS.

## Screenshots

| # | What it proves | File |
|---|----------------|------|
| 1 | Infrastructure deployed from code | ![](docs/screenshots/01-terraform-apply.png) |
| 2 | VPC with 4 subnets across 2 AZs | ![](docs/screenshots/02-vpc-resource-map.png) |
| 3 | Public vs private routing | ![](docs/screenshots/03-route-tables.png) |
| 4 | Only port 80 open | ![](docs/screenshots/04-security-group.png) |
| 5 | Website live | ![](docs/screenshots/05-website.png) |
| 6 | Version hidden, SSH closed | ![](docs/screenshots/06-verify-script.png) |
| 7 | Shell access without SSH | ![](docs/screenshots/07-session-manager.png) |
| 8 | Nginx logs in CloudWatch | ![](docs/screenshots/08-cloudwatch-logs.png) |
| 9 | Memory and disk metrics from the agent | ![](docs/screenshots/09-agent-metrics.png) |
| 10 | Alarm fired (deliberate test) | ![](docs/screenshots/10-alarm-in-alarm.png) |
| 11 | Alert email received | ![](docs/screenshots/11-alarm-email.png) |
| 12 | Everything torn down | ![](docs/screenshots/12-terraform-destroy.png) |

## Cost and teardown

Built and tested in my own AWS account. While deployed it costs about **$0.02 per hour**: the t3.micro instance (~$0.0104/h, Free Tier eligible), its public IPv4 address ($0.005/h), an 8 GB disk, and a few CloudWatch metrics. A 4-hour session is roughly **$0.10**. `./scripts/destroy.sh` removes everything, so nothing keeps charging.

_Estimates from AWS list prices, October 2026; prices in eu-north-1 (Stockholm), where this was built, are similar. Check your own bill in Billing → Cost Explorer._

## 📚 Lessons Learned: Everything That Went Wrong (and How I Fixed It)

Things rarely work first time, and the fixes taught me more than the parts that worked. These are the real problems I hit while building this project, in the order they happened.

### 1. The sandbox wasn't the real world

| | |
|---|---|
| **What happened** | I started in a KodeKloud sandbox. It had hidden limits: only 3 regions, small instance types, a cap of 300 Lambda calls an hour, and DynamoDB fixed at 1 read/write unit. It also gave me new access keys every 3-hour session. |
| **Fix** | I moved to my own AWS account, after setting it up safely: MFA on the root user, a $5 budget alert, and an admin IAM user with its own access keys. Root is never used day to day. |
| **Lesson** | Sandboxes are great for practice, but the design decisions only become real when you own the bill. Set up the budget alert **before** building anything. |

### 2. Deploy failed: "explicit deny in a service control policy"

| | |
|---|---|
| **What I saw** | `not authorized to perform: ssm:GetParameter` and `not authorized to perform: ec2:DescribeAvailabilityZones with an explicit deny in a service control policy` |
| **Cause** | My account belongs to an AWS Organization whose **service control policy (SCP)** only allows **eu-north-1 (Stockholm)**. My code defaulted to **us-east-1**, so the very first lookups (the Ubuntu image ID and the Availability Zone names) were refused. |
| **Fix** | I changed the default region in every project to `eu-north-1`, and set the CLI to match: `aws configure set region eu-north-1`. |
| **Lesson** | An SCP **explicit deny beats everything**, even `AdministratorAccess`. No IAM change can override it. Also, *read the whole error*: the region was printed inside the ARN all along. |

### 3. Stockholm has no t2 instances

| | |
|---|---|
| **What I found** | While moving regions, I checked instance availability: eu-north-1 offers `t3`, `t3a` and Graviton `t4g`, but **not `t2`**. |
| **Fix** | Changed the allowed instance types in `variables.tf` to t3/t3a. |
| **Lesson** | Regions are not identical. Instance families, services and prices differ, so check before you pick one. |

### 4. Forcing the alarm failed with AccessDenied in us-east-1

| | |
|---|---|
| **What I saw** | `aws cloudwatch set-alarm-state ...` → `not authorized to perform: cloudwatch:SetAlarmState on resource: arn:aws:cloudwatch:us-east-1:...` |
| **Cause** | My AWS CLI's default region was still us-east-1, so the command went to the wrong region, where the SCP blocks everything (and where my alarm doesn't even exist). |
| **Fix** | Added `--region eu-north-1` to the command, then made it permanent with `aws configure set region eu-north-1`. The `AWS_REGION` and `AWS_DEFAULT_REGION` environment variables override that setting, so I check them too. |
| **Lesson** | Terraform and the CLI each decide the region separately. When an AWS command fails, the **first** thing to check is which region and account it ran against. |

### 5. stress-ng refused to start: "temp-path '.' must be readable and writeable"

| | |
|---|---|
| **What I saw** | `aborting: temp-path '.' must be readable and writeable` |
| **Cause** | Session Manager opens the shell in `/`, the root of the disk, as `ssm-user`, who isn't allowed to write there. stress-ng needs a writable folder for temporary files. |
| **Fix** | `cd ~` (to `/home/ssm-user`) before running it, or `stress-ng --cpu 2 --timeout 300s --temp-path /tmp`. |
| **Lesson** | Always check **where you are** (`pwd`) and **who you are** (`whoami`) on a server. Many "the tool is broken" errors are really permission or working-folder problems. |

### 6. The CPU alarm test and CPU credits

| | |
|---|---|
| **What I expected** | 2 stress-ng workers on a 2-vCPU t3.micro push CPU near 100%, and the alarm fires after 2 minutes above 70%. |
| **What can get in the way** | t3 instances are *burstable*: they earn CPU credits while idle and spend them to run above a low baseline. In **Standard** mode (which I chose so there are no surprise charges), an instance with an empty credit balance is held near its baseline, so CPU may never reach 70%. |
| **How the alarm fired for me** | <!-- Write ONE honest line: "From real CPU load after ~N minutes" OR "CPU stayed at ~N% because CPUCreditBalance was 0; I tested the alert path with set-alarm-state". --> |
| **Lesson** | Testing monitoring means testing the **whole path**: metric → alarm → SNS → inbox. `set-alarm-state` tests the notification half when the metric can't be pushed high enough. |

### 7. (Portfolio) My diagram image wouldn't show on GitHub

| | |
|---|---|
| **What happened** | The image in my main README showed as a broken link. |
| **Cause** | The `src` held a second `<img>` tag pasted inside the first, and it used a `/blob/` URL, which points to GitHub's web page *about* the file, not the image itself. |
| **Fix** | One clean `<img>` tag with a `/raw/` URL or a relative path, and file names without spaces. |
| **Lesson** | Preview the README on GitHub after every push; small mistakes are obvious to a recruiter. |

### What I'd do differently next time

- Confirm the **account, region and allowed services** before writing any code: `aws sts get-caller-identity` and `aws configure get region`.
- Put the region in **one place** and pass it explicitly to scripts, instead of relying on defaults.
- Keep a running list of errors **while building**, with the exact message, rather than reconstructing them afterwards.

### 📖 What I read to fix these

- [Service control policies (AWS Organizations)](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html): why an explicit deny overrides IAM
- [Environment variables to configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html): how `AWS_REGION` overrides the config file
- [Burstable performance instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances.html): CPU credits, baseline, Standard vs Unlimited
- [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html): shell access with no SSH
- [Creating a CloudWatch alarm that sends email](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)