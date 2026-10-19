# Project 05 – Containerised App on ECS Fargate with GitHub Actions: Complete Guide

**Wednesday 14 October. From the files to a finished project on GitHub, using VS Code and your own AWS account.**

Total time: about 4–5 hours. **Estimated cost: about $0.20–0.40** if you destroy everything the same day. The parts marked "No" cost nothing, so do them first.

⚠️ **Don't push this project to GitHub until Part 8.** The pipeline runs on every push. If it runs before AWS is ready, it fails.

| Part | What you do | Uses AWS (costs money)? |
|------|-------------|----------------------|
| 1 | Check your tools and install Docker Desktop | No |
| 2 | Add the project files (**don't push yet**) | No |
| 3 | Run the tests and the container locally | No |
| 4 | Check your AWS connection | No |
| 5 | First deploy (bootstrap) | **Yes – charges start (~$0.05/hour)** |
| 6 | Check it in the AWS console | Yes |
| 7 | Connect GitHub Actions to AWS (OIDC, no keys) | Yes |
| 8 | Release through the pipeline | Yes |
| 9 | Rollback test | Yes |
| 10 | Logs | Yes |
| 11 | Tear it all down | Yes |
| 12 | Diagram, final push, mark complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_5/05-ecs-fargate-cicd/docs/screenshots/` with **exactly** that file name. This project has **14 images** in total.

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

### Install Docker Desktop (new for this project)

**Windows** (PowerShell): `winget install --id Docker.DockerDesktop -e`, then restart the computer.
**Mac:** `brew install --cask docker`.

Open **Docker Desktop** and wait until it says **Engine running**. Then in VS Code:

```bash
docker version
```

You should see both a **Client** and a **Server** section. If Server is missing, Docker Desktop isn't running.

---
## Part 2 – Add the Project 05 files

### 2.1 Get the latest version of your repo

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git pull
```

### 2.2 Unzip the project

Unzip `project-05-ecs-fargate.zip` **into the `Discovering-Cloud-Engineering` folder** (the one with your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore` or `.gitattributes`, choose **Replace**: they're the same files Project 03 used.

You should now have:

```
Discovering-Cloud-Engineering/
├── .gitignore
├── .gitattributes
├── .github/workflows/
│   └── 05-ecs-deploy.yml                    ← the pipeline: test → build → scan → push → deploy
└── cloud-pro_5/05-ecs-fargate-cicd/
    ├── README.md
    ├── Dockerfile                           ← multi-stage, non-root image
    ├── requirements.txt  requirements-dev.txt
    ├── src/app/main.py                      ← the FastAPI service
    ├── tests/test_main.py                   ← 3 tests
    ├── infrastructure/                      ← ECR, ECS, ALB, IAM, GitHub OIDC role
    ├── scripts/                             ← bootstrap.sh, watch_versions.sh, deploy.sh, destroy.sh
    └── docs/                                ← START-HERE, runbook, ADRs, diagram, screenshots/
```

### 2.3 Go into the project folder

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_5/05-ecs-fargate-cicd
pwd
```

`pwd` should end with `05-ecs-fargate-cicd`. **Every command from here on runs from this folder** unless it says otherwise.

---
## Part 3 – Run the tests and the container locally (free)

### 3.1 Tests

```bash
python -m venv .venv
source .venv/Scripts/activate      # Windows Git Bash
# source .venv/bin/activate        # Mac / Linux
pip install -r requirements-dev.txt
pytest -v
```

Expected: **`3 passed`**.

📸 **`01-pytest-pass.png`**

### 3.2 Run the container on your computer (optional, recommended)

```bash
docker build -t container-app:local .
docker run --rm -p 8000:8000 container-app:local
```

Open http://localhost:8000 in your browser. You should see `{"service":"container-app","version":"local",...}`. Press `Ctrl + C` in the terminal to stop it.

This proves the image works before you pay for anything in AWS.

---
## Part 4 – Check your AWS connection

### 4.1 Make sure VS Code is signed in as your admin user

```bash
aws sts get-caller-identity
```

The `Arn` must end in `:user/masego-admin` (or whatever you named your admin user). If it ends in `:root`, or you get an error, follow *Part A* in the root `BUILD-GUIDE.md` first.

### 4.2 Check the region in the console

Sign in to the AWS console with your admin user's sign-in URL and check the region in the top right says **Europe (Stockholm) eu-north-1**. Your account only allows this region, and resources in other regions won't appear on screen.

---
## Part 5 – Deploy to AWS

### 5.1 Fill in your settings

```bash
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
```

Open `infrastructure/terraform.tfvars` in VS Code and set:

```hcl
owner       = "masegoleroux-commits"
```


Your repository and branch are already filled in as defaults (`masegoleroux-commits/Discovering-Cloud-Engineering`, `main`). If your GitHub username or repo name is different, add:

```hcl
github_repository = "your-username/your-repo"
```

**GitHub sign-in mode.** The default, `ci_auth = "access_keys"`, works in your account: its organisation blocks OIDC, so GitHub uses a locked-down IAM user instead. **Don't add any OIDC lines** to `terraform.tfvars`. In particular, `create_github_oidc_provider = false` would make Terraform look up the OIDC provider, which your account denies.

Only in an account that allows OIDC would you add `ci_auth = "oidc"`.

Save (`Ctrl + S`). `.gitignore` keeps this file off GitHub.

### 5.2 First deploy (bootstrap)

Make sure **Docker Desktop is running**, then:

```bash
chmod +x scripts/*.sh
./scripts/bootstrap.sh
```

This takes 5–10 minutes. It:
1. creates the ECR repository,
2. builds the image and pushes it with the tag `bootstrap`,
3. creates everything else: cluster, service, load balancer, IAM roles and the GitHub deploy role.

Wait for `Apply complete! Resources: 21 added` and outputs including `app_url` and `github_deploy_role_arn`.

📸 **`02-bootstrap.png`** – the `docker push` lines and `Apply complete!`.

It is safe to run bootstrap again: if the `bootstrap` image already exists, it skips the build and push.

---

## Part 6 – Check it in the AWS console

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **ECR** → Private repositories → `container-app-dev-app` → click the `bootstrap` image | The image and its **scan findings** | `03-ecr-images.png` |
| 📸 | **ECS** → Clusters → `container-app-dev-cluster` → Services → `container-app-dev-svc` | **1/1 tasks running**, deployment **Completed** | `04-ecs-service.png` |
| 📸 | **EC2** → Target groups → `container-app-dev-tg` → **Targets** | One target, status **healthy** (can take 1–2 minutes) | `05-target-health.png` |

Open the app:

```bash
terraform -chdir=infrastructure output -raw app_url
```

Open that URL in your browser. You should see `"version": "bootstrap"`. If you get a **503**, the task is still starting: wait a minute and refresh.

📸 **`06-app-bootstrap.png`** – the browser with the address bar and `"version": "bootstrap"`.

---

## Part 7 – Connect GitHub Actions to AWS

**Which way?** With the default (`ci_auth = "access_keys"`, the right choice for your account), skip to **7B**. Use **7A** only if you set `ci_auth = "oidc"`.

### 7A – OIDC (no stored keys)

GitHub won't store any AWS keys. Instead, each workflow run proves it's from **your repo's main branch**, and AWS gives it temporary credentials for one limited role.

#### Copy the role ARN

```bash
terraform -chdir=infrastructure output -raw github_deploy_role_arn
```

It looks like `arn:aws:iam::123456789012:role/container-app-dev-github-deploy`.

#### Save it in GitHub as a variable

1. On GitHub, open your repo → **Settings** → **Secrets and variables** → **Actions**.
2. Click the **Variables** tab (not Secrets) → **New repository variable**.
3. Name: `AWS_DEPLOY_ROLE_ARN` · Value: the ARN you copied → **Add variable**.

A role ARN isn't secret, which is why it's a variable. There's nothing to leak.

#### Screenshot the trust policy

**IAM** → Roles → `container-app-dev-github-deploy` → **Trust relationships** tab. It shows the two conditions: the audience `sts.amazonaws.com` and the subject `repo:masegoleroux-commits/Discovering-Cloud-Engineering:ref:refs/heads/main`.

📸 **`07-github-oidc-role.png`** – **blur the account ID** in the ARNs.

This screenshot is a strong interview talking point: "my pipeline has no long-lived keys, and only my main branch can deploy."

### 7B – Access keys for a locked-down CI user (if your account blocks OIDC)

Terraform created an IAM user just for the pipeline, with the **same narrow permissions** the OIDC role would have: push to one ECR repository, update one ECS service, and nothing else. You create its key yourself, so the secret never appears in Terraform's files.

1. Get the user's name:
   ```bash
   terraform -chdir=infrastructure output -raw github_ci_user      # container-app-dev-github-ci
   ```
2. **IAM** → **Users** → `container-app-dev-github-ci` → **Security credentials** → **Create access key** → **Application running outside AWS** → **Create access key**. Copy both values (you only see the secret once).
3. On GitHub: repo → **Settings** → **Secrets and variables** → **Actions** → **Secrets** tab → **New repository secret**, twice:

   | Secret name | Value |
   |-------------|-------|
   | `AWS_ACCESS_KEY_ID` | the access key ID |
   | `AWS_SECRET_ACCESS_KEY` | the secret access key |

4. Make sure there is **no** `AWS_DEPLOY_ROLE_ARN` variable on the **Variables** tab. The pipeline uses the keys only when that variable is empty.

📸 **`07-github-oidc-role.png`** – for this route, screenshot the CI user's **Permissions** tab (its policy allows only ECR push, ECS deploy and passing the two task roles) and the GitHub **Secrets** list (names only, values are hidden). Caption it "CI user: least-privilege access keys (account blocks OIDC)".

In your Lessons learned, explain why: the account's organisation policy blocks OIDC providers, so you used the next-best option and limited what the keys can do. `./scripts/destroy.sh` deletes the user and its key.

---

## Part 8 – Release through the pipeline

### 8.1 Make a visible change

Open `src/app/main.py` and change the `root()` function so it returns a message too:

```python
@app.get("/")
def root():
    """Shows which version and which task answered, useful to watch a rolling deploy."""
    return {
        "service": "container-app",
        "version": APP_VERSION,
        "task_host": socket.gethostname(),
        "message": "Released by GitHub Actions",
    }
```

Save, and check the tests still pass: `pytest -v`.

### 8.2 Watch the app in a second terminal

Click the **+** in the VS Code terminal panel to open a second terminal, then:

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_5/05-ecs-fargate-cicd
./scripts/watch_versions.sh
```

It prints the app's response every 3 seconds. Leave it running.

### 8.3 Push only Project 05

In the **first** terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/05-ecs-deploy.yml cloud-pro_5
git status        # only these files; no tfvars, tfstate or .venv
git commit -m "feat(05): containerised app on ECS Fargate with OIDC pipeline"
git push
```

On GitHub: **Actions** → **05 ECS Fargate deploy** → the new run. It takes about 5–8 minutes: test → build → Trivy scan → push → deploy → wait for stability.

📸 **`08-pipeline-success.png`** – both jobs green.
📸 **`09-trivy-scan.png`** – click into **build-scan-deploy** → open the **Scan image** step, showing the findings table or no CRITICAL findings.
📸 **`10-rolling-deploy.png`** – the `watch_versions.sh` terminal showing responses switch from `"bootstrap"` to the commit SHA with the new message, and **no "no response" lines**. That's your zero-downtime proof.

Go back into the project folder: `cd cloud-pro_5/05-ecs-fargate-cicd`

---

## Part 9 – Rollback test (deliberate – label it as a test)

Break the health check on purpose. In `src/app/main.py`, add an import at the top and change `health()`:

```python
from fastapi.responses import JSONResponse

@app.get("/health")
def health():
    return JSONResponse({"status": "broken on purpose"}, status_code=500)
```

The pipeline runs the tests before it deploys, and the health test would now fail and stop it. So **also** change the test temporarily: in `tests/test_main.py`, make `test_health_returns_ok` expect `500` and `{"status": "broken on purpose"}`. Then:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add cloud-pro_5
git commit -m "test(05): deliberately break /health to test the rollback"
git push
```

The new task fails its health checks, ECS keeps retrying, and after roughly **10 failed attempts** (about 15–20 minutes) the deployment circuit breaker rolls the service back. Keep `watch_versions.sh` running: the old version keeps answering the whole time. The pipeline run ends **failed**, which is the expected result.

**ECS** → the service → **Deployments** tab and **Events** tab show the failed deployment and the rollback.

📸 **`11-circuit-breaker-rollback.png`** – the rollback event. Caption it "Deliberate failure test".

Then **put both files back** (`health()` returns `{"status": "ok"}` and the test expects `200`), and push again so the pipeline goes green:

```bash
git add cloud-pro_5
git commit -m "fix(05): restore /health after the rollback test"
git push
```

Stop `watch_versions.sh` with `Ctrl + C`.

---

## Part 10 – Logs

**CloudWatch** → Log groups → `/ecs/container-app-dev` → a stream starting with `app/`. The uvicorn lines show the load balancer's `GET /health` checks.

📸 **`12-cloudwatch-logs.png`**

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

📸 **`13-terraform-destroy.png`**

This also deletes the images in ECR. The GitHub variable can stay; the next deploy creates a new role with the same name and ARN.

**Leftover check:** make sure nothing from this project is still running (and costing money):

```bash
aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=container-app \
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
00-architecture.png       05-target-health.png          10-rolling-deploy.png
01-pytest-pass.png        06-app-bootstrap.png          11-circuit-breaker-rollback.png
02-bootstrap.png          07-github-oidc-role.png       12-cloudwatch-logs.png
03-ecr-images.png         08-pipeline-success.png       13-terraform-destroy.png
04-ecs-service.png        09-trivy-scan.png
```

### 12.3 Write your lessons learned

Open this project's `README.md`, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

This final push only changes `docs/` and `README.md`, so it **doesn't** start a deploy (the workflow ignores docs-only changes).

### 12.4 Push only Project 05

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/05-ecs-deploy.yml cloud-pro_5
git status
```

`git status` must list only those files. Check that **no** `terraform.tfvars`, `.tfstate`, `.venv` or `.csv` key file appears. Then:

```bash
git commit -m "docs(05): add screenshots, diagram and lessons learned"
git push
```

### 12.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 05's status to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 05 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---
## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `Cannot connect to the Docker daemon` | Docker Desktop isn't running | Open it and wait for **Engine running** |
| `EntityAlreadyExists` for the OIDC provider | Your account already has one | Set `create_github_oidc_provider = false` and run `./scripts/deploy.sh` |
| `not authorized to perform: iam:ListOpenIDConnectProviders` (or `CreateOpenIDConnectProvider`) **with an explicit deny in a service control policy** | `terraform.tfvars` still has `ci_auth = "oidc"` or `create_github_oidc_provider = false` | Delete both lines (the default `access_keys` needs neither), run `./scripts/deploy.sh`, then follow Part 7B |
| `not authorized to perform: iam:CreateUser` with an explicit deny | Your account also blocks creating IAM users | Last resort: save your own admin user's access keys as the two GitHub secrets, and note the risk in your Lessons learned |
| Pipeline: `Credentials could not be loaded` with access keys | Secrets missing or misnamed | They must be **Secrets** named exactly `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` |
| Pipeline: `Not authorized to perform sts:AssumeRoleWithWebIdentity` | Repo or branch doesn't match the trust policy | Check `github_repository` (exact spelling and case) and that you pushed to `main` |
| Pipeline: `Could not load credentials` / role input empty | GitHub variable missing or misnamed | It must be a **Variable** named exactly `AWS_DEPLOY_ROLE_ARN` |
| Pipeline fails at "Download current task definition" | Infrastructure not deployed (or destroyed) | Run `./scripts/bootstrap.sh` first; only push after Part 5 |
| Task stops with `CannotPullContainerError` | Task can't reach ECR | Check `assign_public_ip = true` and the task egress rule |
| `exec format error` in the logs | Image built for ARM on an Apple Silicon Mac | Build with `--platform linux/amd64` (bootstrap does this; GitHub runners are x86) |
| Target `unhealthy`, tasks keep restarting | Health path, port or security group mismatch | Run the container locally and open `/health`; check the task SG allows the ALB SG |
| 503 from the load balancer | No healthy task yet | Wait 1–2 minutes |
| Push rejected: tag already exists | Immutable tags working as intended | Use a new commit, or destroy and bootstrap again |
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
