# ☁️ Discovering Cloud Engineering

**Aspiring Junior Cloud / DevOps Engineer** building hands-on AWS projects with Terraform, Python, containers and CI/CD, with a focus on security and cost control.

📍 Johannesburg, South Africa · 🎯 Open to Junior Cloud, DevOps and Platform Engineer roles

<!-- Add your links here before publishing -->
[LinkedIn](https://www.linkedin.com/in/your-profile) · [Email](mailto:your-email@example.com) · [CV](link-to-your-cv)

---

## ⚡ At a Glance (30-second summary)

- **12 AWS projects in two tracks:** the **Cloud Engineering** track (01–07) is built; the **Networking** track (08–12) is being built 19–23 October 2026. Each project is deployed from code (Infrastructure as Code) and torn down after testing to keep costs near zero.
- **Security first:** least-privilege IAM, encryption, no SSH access, secrets in AWS Secrets Manager, vulnerability scanning in CI/CD, and an account-wide audit trail with compliance rules.
- **Tested and automated:** unit tests, security tests, and GitHub Actions pipelines.
- **Cost-aware by design:** built in my own AWS account with a budget alert; every README states what the project costs per hour and how it's torn down.
- **Honest about what went wrong:** every project ends with a **Lessons Learned** section of the real errors I hit and how I fixed them.

## 🧰 Core Skills

| Area | Tools |
|------|-------|
| **Cloud (AWS)** | EC2, VPC, S3, Lambda, API Gateway, DynamoDB, RDS, ECS Fargate, ECR, ALB, Step Functions, EventBridge, SQS, SNS |
| **Infrastructure as Code** | Terraform, CloudFormation |
| **Containers** | Docker (multi-stage, non-root images) |
| **CI/CD** | GitHub Actions, Trivy image scanning |
| **Security** | IAM least privilege, KMS, Secrets Manager, CloudTrail, AWS Config, SSM Session Manager |
| **Networking** | VPC design, public and private subnets, route tables, internet gateway, security groups |
| **Monitoring** | CloudWatch Logs, metrics and alarms, SNS alerting |
| **Languages & OS** | Python, T-SQL, Bash, Linux (Ubuntu, Amazon Linux) |
| **Testing** | pytest, moto, Postman/Newman |

## 📂 Projects

### Cloud Engineering track

| # | Project | What it demonstrates | Key tech | Status |
|---|---------|----------------------|----------|--------|
| 01 | [Static Website on S3](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_1/01-static-website-s3) | Infrastructure as Code basics: provision, deploy and destroy a website from code | S3, Terraform | ✅ Complete (torn down to avoid cost) |
| 02 | [Secure Payments Data API](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_2/02-secure-payments-api) | Protecting sensitive data: card masking, stored-procedure-only access, 27 automated security tests | Lambda, API Gateway, RDS SQL Server, Secrets Manager, KMS, CloudFormation | 🟡 Code complete, deployment in progress |
| 03 | [Serverless Notes API](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_3/03-serverless-notes-api) | Serverless REST API with least-privilege IAM and zero-cost unit tests | API Gateway, Lambda, DynamoDB, Terraform | ✅ Complete (torn down to avoid cost) |
| 04 | [VPC + Hardened Web Server](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_4/04-vpc-hardened-web-server) | Networking from scratch and server hardening with no SSH | VPC, EC2, SSM, CloudWatch, Terraform | ✅ Complete (torn down to avoid cost) |
| 05 | [Containerised App on ECS Fargate](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_5/05-ecs-fargate-cicd) | Automated releases from git push to production, with security scanning and auto-rollback | Docker, ECS Fargate, ECR, GitHub Actions, Trivy | ✅ Complete (torn down to avoid cost) |
| 06 | [Event-Driven CSV Pipeline](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_6/06-event-driven-csv-pipeline) | Reliable data processing: retries, error handling and no silently lost files | S3, EventBridge, Step Functions, SQS | ✅ Complete (torn down to avoid cost) |
| 07 | [AWS Security Baseline](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_7/07-aws-security-baseline) | Account-wide auditing, compliance checks and security alerting, proved with deliberate test violations | CloudTrail, AWS Config, CloudWatch | ✅ Complete (torn down to avoid cost) |

### 🌐 Networking track

| # | Project | What it demonstrates | Key tech | Status |
|---|---------|----------------------|----------|--------|
| 08 | [Hub-and-Spoke Network with Transit Gateway](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_8/08-transit-gateway-hub-spoke) | Controlling and proving which VPCs can talk to which | Transit Gateway, TGW route tables, Reachability Analyzer | 📅 Building Mon 19 Oct 2026 |
| 09 | [Private Subnets with a NAT Instance and Flow Logs](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_9/09-nat-instance-flow-logs) | Outbound internet for private subnets built from first principles, and reading real traffic | NAT instance, iptables, Elastic IP, VPC Flow Logs, Logs Insights | 📅 Building Tue 20 Oct 2026 |
| 10 | [Zero-Internet Workload with VPC Endpoints](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_10/10-vpc-endpoints-zero-internet) | AWS access with no route to the internet, and no way to copy data out | Gateway + interface endpoints, endpoint policies, `aws:SourceVpce` | 📅 Building Wed 21 Oct 2026 |
| 11 | [Private DNS and Route 53 DNS Firewall](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_11/11-private-dns-dns-firewall) | Internal names, plus blocking bad domains before a connection is made | Route 53 private zones, Resolver DNS Firewall, query logging | 📅 Building Thu 22 Oct 2026 |
| 12 | [HA Web Tier behind CloudFront and AWS WAF](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_12/12-cloudfront-waf-ha-web) | How a real public site is fronted, protected and kept running when a server fails | CloudFront, AWS WAF, ALB, Auto Scaling, origin protection | 📅 Building Fri 23 Oct 2026 |

### 🗓️ Release schedule

The Cloud Engineering track (03–07) was published from **Monday 12 to Thursday 15 October 2026**. The Networking track (08–12) follows from **Monday 19 to Friday 23 October 2026**.

---

## 🏗️ Architecture Diagrams

Each diagram shows how the AWS services in a project connect. Click a project to expand it.

### Cloud Engineering track

<details>
<summary><b>01 – Static Website on S3</b></summary>

<img src="https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/blob/main/AWS%20Cloud%20Architecture%20Diagram/01-static-website-s3.svg" alt="Static website on S3 architecture diagram" width="900">

Terraform creates everything; visitors read the site straight from the S3 website endpoint.

</details>

<details>
<summary><b>02 – Secure Payments Data API</b></summary>

<img src="https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/raw/main/AWS%20Cloud%20Architecture%20Diagram/AWS%20Cloud%20Architecture%20Diagram%20%281%29_edited.png" alt="Secure Payments API architecture diagram" width="900">

The API reaches the database only through two stored procedures; credentials come from Secrets Manager.

</details>

<details>
<summary><b>03 – Serverless Notes API</b></summary>

<img src="https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/blob/main/AWS%20Cloud%20Architecture%20Diagram/03-serverless-notes-api.drawio" alt="Serverless Notes API architecture diagram" width="900">

One function handles all four routes; its IAM role can touch only the notes table and its own logs.

</details>

<details>
<summary><b>04 – VPC + Hardened Web Server</b></summary>

<img src="https://raw.githubusercontent.com/masegoleroux-commits/Discovering-Cloud-Engineering/main/AWS%20Cloud%20Architecture%20Diagram/04-vpc-hardened-web-server.svg" alt="VPC and hardened web server architecture diagram" width="900">

Only port 80 is open. Administration goes through SSM, so there is no SSH port or key pair.

</details>

<details>
<summary><b>05 – Containerised App on ECS Fargate</b></summary>

<img src="https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/blob/main/AWS%20Cloud%20Architecture%20Diagram/05-ecs-fargate-cicd.png" alt="ECS Fargate CI/CD architecture diagram" width="900">

A release is blocked if Trivy finds a critical vulnerability, and ECS rolls back automatically if the new version fails health checks.

</details>

<details>
<summary><b>06 – Event-Driven CSV Pipeline</b></summary>

<img src="https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/blob/main/AWS%20Cloud%20Architecture%20Diagram/06-event-driven-csv-pipeline.drawio.svg" alt="Event-driven CSV pipeline architecture diagram" width="900">

Temporary errors are retried; invalid files are never retried and always end up in the dead-letter queue with a reason.

</details>

<details>
<summary><b>07 – AWS Security Baseline</b></summary>

<img src="https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/blob/main/AWS%20Cloud%20Architecture%20Diagram/04-vpc-hardened-web-server.drawio" alt="AWS security baseline architecture diagram" width="900">

CloudTrail records who did what; AWS Config checks whether resources break the rules. Together they detect and explain issues.

</details>

### 🌐 Networking track

The designs for projects 08–12. They show what each project will build; screenshots of the real deployments are added as each one is finished.

<details>
<summary><b>08 – Hub-and-Spoke Network with Transit Gateway</b> (📅 building Mon 19 Oct)</summary>

```mermaid
flowchart TB
  subgraph TGW["Transit Gateway tgw-hub-dev-tgw"]
    SRT["shared-rt<br/>routes: app, data"]
    PRT["spokes-rt<br/>routes: shared only"]
  end
  S["shared VPC<br/>10.100.0.0/16"] <-->|attachment| SRT
  A["app VPC<br/>10.101.0.0/16"] <-->|attachment| PRT
  D["data VPC<br/>10.102.0.0/16"] <-->|attachment| PRT
  A -. "blocked: no route in spokes-rt" .- D
```

App and data VPCs can reach shared services but not each other. The block comes from routing alone, and Reachability Analyzer proves it.

</details>

<details>
<summary><b>09 – Private Subnets with a NAT Instance and Flow Logs</b> (📅 building Tue 20 Oct)</summary>

```mermaid
flowchart LR
  subgraph VPC["VPC 10.30.0.0/16"]
    subgraph PRIV["Private subnet 10.30.11.0/24"]
      APP["App server<br/>no public IP"]
    end
    subgraph PUB["Public subnet 10.30.1.0/24"]
      NAT["NAT instance t4g.micro<br/>iptables MASQUERADE"]
    end
  end
  APP -->|"0.0.0.0/0 → NAT ENI"| NAT
  NAT -->|"Elastic IP"| IGW["Internet Gateway"] --> NET["Internet"]
  VPC -. "every connection" .-> FL["VPC Flow Logs<br/>CloudWatch Logs Insights"]
  NAT -. "health" .-> AL["Alarm → auto-recover + email"]
```

The private server has no public IP; all its outbound traffic leaves through a NAT instance I configure myself, and every connection is recorded in Flow Logs.

</details>

<details>
<summary><b>10 – Zero-Internet Workload with VPC Endpoints</b> (📅 building Wed 21 Oct)</summary>

```mermaid
flowchart LR
  subgraph VPC["VPC 10.40.0.0/16 – no internet gateway, no NAT"]
    EC2["Private workload<br/>t4g.micro"]
    IE["Interface endpoints<br/>ssm · ssmmessages · ec2messages"]
    RT["Route table<br/>local + S3/DynamoDB prefix lists"]
  end
  EC2 -->|HTTPS| IE --> SSM["Systems Manager"]
  EC2 --> RT -->|"S3 gateway endpoint<br/>policy: data bucket only"| S3D[("Data bucket<br/>confidential/ readable only via VPCE")]
  RT -->|"DynamoDB gateway endpoint"| DDB[("Events table")]
  RT -. "blocked by endpoint policy" .-> S3O[("Any other bucket")]
  LAP["My laptop (admin)"] -. "AccessDenied by bucket policy" .-> S3D
```

No internet gateway, no NAT: AWS services are reached privately through endpoints, and endpoint and bucket policies stop data leaving.

</details>

<details>
<summary><b>11 – Private DNS and Route 53 DNS Firewall</b> (📅 building Thu 22 Oct)</summary>

```mermaid
flowchart LR
  C["Client in the VPC"] -->|"DNS question"| RES["Route 53 Resolver<br/>(VPC +2 address)"]
  RES --> FW{"DNS Firewall<br/>rule group"}
  FW -->|"doubleclick.net"| NX["BLOCK → NXDOMAIN"]
  FW -->|"example.org"| SH["BLOCK → sinkhole.corp.internal<br/>192.0.2.1"]
  FW -->|"example.net"| AL["ALERT → answer + flag"]
  FW -->|"everything else"| PZ["Private zone corp.internal<br/>app · db · api"]
  FW --> PUB["Public DNS"]
  RES -. "every query" .-> QL["Query logs → CloudWatch<br/>Logs Insights"]
```

Every DNS question passes the firewall first: bad domains are blocked, sinkholed or flagged, and internal names resolve only inside the VPC.

</details>

<details>
<summary><b>12 – HA Web Tier behind CloudFront and AWS WAF</b> (📅 building Fri 23 Oct)</summary>

```mermaid
flowchart LR
  U["Visitors"] -->|HTTPS| CF["CloudFront"]
  CF -->|"HTTP + secret header"| ALB["Application Load Balancer<br/>+ AWS WAF (regional)<br/>public subnets a/b<br/>SG: CloudFront prefix list only"]
  subgraph PRIV["Private subnets a / b (no internet route)"]
    W1["Web server AZ a"]
    W2["Web server AZ b"]
  end
  ALB --> W1
  ALB --> W2
  ASG["Auto Scaling group<br/>min 2 · max 4 · CPU 50%"] -. manages .- PRIV
  PRIV -->|"packages via S3 gateway endpoint"| S3[("Amazon Linux repos in S3")]
  X["Anyone hitting the ALB directly"] -. "dropped / 403" .-> ALB
```

Visitors reach the site only through CloudFront and a WAF-protected load balancer; servers in two AZs replace themselves if they fail.

</details>

> Diagrams are written in [Mermaid](https://mermaid.js.org/), which GitHub renders automatically, so they stay up to date with the code.

---

## 🔍 Project Details

### Cloud Engineering track

### 01 – Static Website on S3

A website hosted on Amazon S3 and deployed entirely with Terraform: bucket creation, static hosting, a public-read policy for the site files, and the page upload.

**Shows:** the core Infrastructure as Code workflow (`init`, `plan`, `apply`, `destroy`) and cost awareness. The live site was taken down to avoid charges and can be redeployed in one command.

### 02 – Secure Payments Data API

A secured REST and SOAP API in front of a SQL Server payments database, using synthetic (made-up) data.

**Shows:**
* **Data protection:** card numbers masked in T-SQL; credentials stored in AWS Secrets Manager
* **Least privilege:** the API login can run only two specific stored procedures
* **Database skills:** tables, stored procedures, roles, and versioned migrations with rollback
* **Security testing:** 27 Postman/Newman assertions covering SQL injection and XML attacks
* **Networking:** deployed inside a private VPC

**Status:** code complete, linted and unit-tested. Deployment is in progress. I've solved several sandbox restrictions (password generation, inline IAM policies, policy deletion) and am troubleshooting a CloudFormation rollback.

### 03 – Serverless Notes API

A REST API to create, read, list and delete notes, built on API Gateway, Python Lambda and DynamoDB, all deployed with Terraform.

**Shows:**
* **Least-privilege IAM:** the function can perform 4 actions on one table and nothing else
* **Testing without cost:** unit tests run against mocked AWS (moto), never touching the cloud
* **Guardrails:** API throttling and validated limits for timeout and memory

### 04 – VPC + Hardened Web Server

A two-zone network built by hand, with one Nginx web server.

**Shows:**
* **Networking:** public and private subnets, route tables and an internet gateway, written without pre-built modules
* **No SSH:** administration only through AWS SSM Session Manager, so there is no open admin port
* **Hardening:** IMDSv2 required, encrypted disk, server version hidden
* **Monitoring:** logs and metrics in CloudWatch, with email alarms
* **Real-world constraints:** fixed deployments blocked by my AWS Organization's region policy (SCP) by moving everything to eu-north-1

### 05 – Containerised App on ECS Fargate

A Python web service packaged in a container and released automatically on every code push.

**Shows:**
* **CI/CD:** test → build → security scan → push → deploy, blocked if critical vulnerabilities are found
* **Safe releases:** zero-downtime rolling deploys with automatic rollback if the new version fails
* **Secure containers:** small multi-stage image running as a non-root user
* **Least-privilege CI:** when my organisation blocked OIDC, GitHub Actions used a dedicated IAM user that can only update this one app
* **Supply-chain safety:** third-party GitHub Actions pinned to a commit SHA after a pinned tag disappeared

### 06 – Event-Driven CSV Pipeline

Uploading a CSV file automatically starts a workflow that validates it and loads it into a database.

**Shows:**
* **Reliability:** automatic retries for temporary errors; rejected files go to a dead-letter queue with the reason
* **Alerting:** email on every success and every rejection
* **Safe re-runs:** uploading the same file twice doesn't create duplicate records

### 07 – AWS Security Baseline

Account-wide security controls for my AWS account.

**Shows:**
* **Audit trail:** every API call recorded, with tamper-evident logs
* **Compliance checks:** 6 automated rules covering public buckets, open SSH, encryption, instance metadata security and the account password policy
* **Alerting:** alarms for root account use, denied API calls, firewall changes and logins without MFA
* **Proof it works:** deliberately created violations (open SSH, IMDSv1, an unencrypted disk, a denied API call), clearly labelled as tests, and a findings log with a code review of projects 03–06 against the same rules


### 🌐 Networking track (building 19–23 October 2026)

These are the plans for each project. Each section will be updated with real results, screenshots and lessons learned as the project is finished.

### 08 – Hub-and-Spoke Network with Transit Gateway

Three VPCs joined through one Transit Gateway, with route tables that let the app and data networks reach shared services but not each other.

**Will show:**
* **Segmentation by routing:** separate Transit Gateway route tables for shared services and spokes
* **IP planning:** non-overlapping address ranges across three VPCs and two Availability Zones
* **Proof, not assumption:** VPC Reachability Analyzer showing which paths are reachable and which are blocked, and why
* **Policy as code:** one Terraform setting opens or closes the app-to-data path

### 09 – Private Subnets with a NAT Instance and Flow Logs

A private server with no public IP that reaches the internet through a NAT router I configure myself.

**Will show:**
* **NAT from first principles:** IP forwarding, iptables MASQUERADE and the EC2 source/destination check
* **Traffic visibility:** VPC Flow Logs with saved Logs Insights queries for rejected traffic, top talkers and outbound traffic
* **Self-healing:** a CloudWatch alarm that recovers the NAT instance automatically
* **Cost trade-off:** roughly 70% cheaper than a managed NAT gateway, with the reliability trade-offs written down

### 10 – Zero-Internet Workload with VPC Endpoints

A server in a VPC with no internet route at all, which still uses S3, DynamoDB and Systems Manager privately.

**Will show:**
* **Private access to AWS:** gateway endpoints for S3 and DynamoDB, interface endpoints with private DNS for Systems Manager
* **Data-exfiltration guard:** endpoint policies that only allow the project's own bucket and table
* **Defence in depth:** a bucket policy that refuses even an administrator outside the VPC

### 11 – Private DNS and Route 53 DNS Firewall

Internal names that exist only inside the VPC, and a DNS firewall that stops bad domains before a connection is made.

**Will show:**
* **Private DNS:** a Route 53 private hosted zone with internal records
* **DNS Firewall:** three actions: block, sinkhole and alert
* **Visibility:** every DNS query logged and searchable with Logs Insights

### 12 – HA Web Tier behind CloudFront and AWS WAF

A web tier across two Availability Zones, reachable only through CloudFront and an AWS WAF-protected load balancer.

**Will show:**
* **High availability:** an Auto Scaling group across two AZs that replaces failed servers
* **Edge protection:** AWS WAF with a rate limit and AWS managed rule sets
* **Origin protection:** the load balancer only accepts CloudFront's IP ranges and a secret header
* **Private servers:** no internet route; packages install through an S3 gateway endpoint

---

## 💡 How I Work

- **Everything is code:** each project can be rebuilt from scratch and fully deleted with one command.
- **Cost-conscious:** resources are torn down after testing; nothing runs unnecessarily.
- **Documented decisions:** each project includes architecture diagrams, decision records explaining why I chose one option over another, and a runbook.
- **Learning from failure:** every project's README ends with the real errors I hit, their cause and the fix.
- **Honest results:** test data is synthetic and labelled; any deliberate failures or load tests are clearly marked.

## 🤝 Let's Connect

I'm actively looking for Junior Cloud, DevOps or Platform Engineer opportunities. I'd be glad to walk you through any of these projects.

[LinkedIn](https://www.linkedin.com/in/your-profile) · [Email](mailto:your-email@example.com)
