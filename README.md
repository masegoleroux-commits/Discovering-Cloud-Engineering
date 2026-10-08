# ☁️ Discovering Cloud Engineering

**Kalimera!** Welcome to, a journey into cloud engineering where I share my passion for building, automating and securing infrastructure, along with a curated collection of my hands-on cloud projects.

<p align="center">
  <img src="https://media0.giphy.com/media/v1.Y2lkPTc5MGI3NjExaDlzZjU5dmk4MjBrajY2ZWthanU0YmU1Zm9hMnhqbzVoOGM0cGZ2ZyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/26xBF35LZZva64nuw/giphy.gif" alt="Project Preview">
</p>
## 📅 Project Schedule

Expect a **new cloud project every week** as I keep building and sharing what I learn.

## 🚀 Embark on the Cloud Adventure

In this repository you'll find a growing set of cloud projects, from simple static websites hosted on object storage to automated pipelines, containerised applications and monitored, production-style environments. Each project is small, self-contained and documented so you can read it, run it and learn from it.

## 🛠️ Technologies Explored

- **AWS / Azure / GCP**: Core cloud services for compute, storage, networking and identity.
- **Terraform**: Infrastructure as Code to provision repeatable, version-controlled environments.
- **Docker & Kubernetes**: Packaging applications into containers and running them at scale.
- **CI/CD (GitHub Actions)**: Automating testing, building and deployment.
- **Linux & Bash**: The everyday foundation of cloud work.
- **Monitoring & Logging**: Observing systems with tools like CloudWatch, Prometheus and Grafana.
- **Cloud Security**: IAM, least privilege, encryption and secure-by-default configurations.

## 👋 For Recruiters

Dear recruiters, welcome! As you explore this portfolio you'll see a steady journey of growth in cloud engineering. Each project shows practical skills in provisioning infrastructure, automating deployments and following good security and cost practices. Feel free to explore the code, review the documentation and picture how I could contribute to your team.

## 📂 Projects

| # | Project | Description | Tech |
|---|---------|-------------|------|
| 01 | [Static Website on S3](https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering/tree/main/cloud-pro_1/01-static-website-s3) | A static website hosted on Amazon S3, fully provisioned with Terraform. | AWS S3, Terraform | but down due to cost 
| 2  | [Secure Payments Data API](https://github.com/<your-username>/payments-api) | Least-privilege REST and SOAP API over a SQL Server payments database (synthetic data). Card numbers masked in T-SQL, API login limited to stored procedures, credentials in Secrets Manager, versioned migrations with rollback, and 27 Postman/Newman assertions covering SQL injection and XML attacks. | AWS Lambda, API Gateway, RDS SQL Server, T-SQL, Secrets Manager, KMS, VPC, CloudFormation, Python, Postman/Newman, GitHub Actions 
| 03  | *Coming next week...* | | |

### 01 – Static Website on S3

A simple website hosted on Amazon S3 and deployed entirely with Terraform. The project creates an S3 bucket, enables static website hosting, sets a public-read policy for the site files and uploads the HTML page. It shows the core Infrastructure as Code workflow: `init`, `plan`, `apply` and `destroy`.

### 02 – Secure Payments Data API

A secured API in front of a SQL Server payments database with made-up data.

**What It Shows:**
* **T-SQL & Database:** Custom tables, stored procedures, roles, and versioned migrations with rollback
* **Least-Privilege Access:** API access strictly restricted to running two specific stored procedures
* **Data Protection & Secrets:** Native T-SQL card masking and credentials managed via AWS Secrets Manager
* **Network & Protocols:** Provisioned inside a private VPC supporting both REST and SOAP endpoints
* **Automated Security Testing:** 27 Postman/Newman test assertions covering SQL injection and XML attacks

**Status:**
* **Code Quality:** Complete, fully linted, and unit-tested
* **Deployment Status:** In progress (pending successful deployment)
* **Resolved Hurdles:** Fixed sandbox blockages around dynamic password generation, inline IAM policies, and policy deletion
* **Current Blocker:** Last CloudFormation attempt rolled back prior to log capture; active troubleshooting ongoing
## 🤝 Connect and Collaborate
