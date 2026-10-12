# Project 03 – Serverless Notes API: Complete Guide

**From an empty computer to a finished project on GitHub, using VS Code and the KodeKloud AWS sandbox.**

Total time: about 3–4 hours the first time. The KodeKloud playground lasts **3 hours**, so do Parts 1–4 *before* you start the playground.

| Part | What you do | Needs the playground? |
|------|-------------|----------------------|
| 1 | Install the tools (once) | No |
| 2 | Set up VS Code (once) | No |
| 3 | Get your GitHub repo and add the project files | No |
| 4 | Run the tests and push the code to GitHub | No |
| 5 | Start KodeKloud and connect VS Code to AWS | **Yes – timer starts** |
| 6 | Deploy to AWS | Yes |
| 7 | Check it works and take screenshots | Yes |
| 8 | Tear it all down | Yes |
| 9 | Add the diagram, push the screenshots, mark it complete | No |

Every 📸 means: take a screenshot and save it in `cloud-pro_3/03-serverless-notes-api/docs/screenshots/` with **exactly** that file name.

---

## Part 1 – Install the tools (only once)

### Windows

Open **PowerShell** (Start menu → type "PowerShell") and paste these lines one at a time:

```powershell
winget install --id Git.Git -e
winget install --id Microsoft.VisualStudioCode -e
winget install --id Amazon.AWSCLI -e
winget install --id Hashicorp.Terraform -e
winget install --id Python.Python.3.12 -e
```

When the Python installer shows a box called **"Add python.exe to PATH"**, tick it.

### Mac

Install Homebrew from https://brew.sh first, then in Terminal:

```bash
brew install git awscli terraform python@3.12
brew install --cask visual-studio-code
```

### Check everything installed

**Close and reopen** the terminal (new tools only appear in new windows), then:

```bash
git --version
aws --version
terraform -version
python --version
```

Each line should print a version number. If one says "not recognized", restart the computer and try again.

---

## Part 2 – Set up VS Code (only once)

1. Open **VS Code**.
2. **Make Git Bash the terminal (Windows only):** press `Ctrl + Shift + P`, type **Terminal: Select Default Profile**, choose **Git Bash**.
3. **Install extensions:** click the Extensions icon on the left (four squares) and install:
   - **HashiCorp Terraform**
   - **Python** (by Microsoft)
   - **Draw.io Integration** (by Henning Dieterichs)
   - **Markdown Preview Mermaid Support**
4. **Format on save:** press `Ctrl + ,`, search **format on save**, tick it.

---

## Part 3 – Get your repo and add the project files

### 3.1 Download your repo (first time only)

In VS Code press ``Ctrl + ` `` to open the terminal, then:

```bash
cd ~/Documents
git clone https://github.com/masegoleroux-commits/Discovering-Cloud-Engineering.git
```

Tell Git who you are (once per computer):

```bash
git config --global user.name "Your Name"
git config --global user.email "the-email-on-your-github-account@example.com"
```

### 3.2 Open the repo in VS Code

**File → Open Folder…** → choose `Documents/Discovering-Cloud-Engineering`.

### 3.3 Add the Project 03 files

Unzip `project-03-notes-api.zip` **into the `Discovering-Cloud-Engineering` folder** (the one that has your main `README.md`). If Windows asks about merging folders, choose **Yes**. If it asks to replace `.gitignore`, choose **Replace** unless you added your own rules to it.

Your folder should now look like this:

```
Discovering-Cloud-Engineering/
├── README.md                         ← your existing portfolio README
├── .gitignore                        ← keeps secrets and state files out of GitHub
├── .gitattributes                    ← keeps scripts working on Windows
├── .github/workflows/
│   └── 03-notes-api-ci.yml           ← runs the tests on GitHub
├── cloud-pro_1/ ...                  ← your existing project 01
└── cloud-pro_3/03-serverless-notes-api/
    ├── README.md
    ├── requirements-dev.txt
    ├── src/handler.py                ← the Lambda code
    ├── tests/test_handler.py         ← 9 unit tests
    ├── infrastructure/               ← Terraform files
    ├── scripts/                      ← deploy.sh, smoke_test.sh, destroy.sh
    └── docs/                         ← runbook, ADRs, diagram, screenshots/
```

### 3.4 Go into the project folder

In the VS Code terminal:

```bash
cd ~/Documents/Discovering-Cloud-Engineering/cloud-pro_3/03-serverless-notes-api
pwd
```

`pwd` should end with `03-serverless-notes-api`. **Every command from here on runs from this folder** unless it says otherwise.

---

## Part 4 – Run the tests and push the code (no AWS needed)

### 4.1 Create a Python environment and run the tests

```bash
python -m venv .venv
source .venv/Scripts/activate      # Windows Git Bash
# source .venv/bin/activate        # Mac / Linux: use this line instead
pip install -r requirements-dev.txt
pytest -v
```

Your prompt now starts with `(.venv)`. The tests should end with **`9 passed`**.

📸 **`01-pytest-pass.png`** – the list of tests and `9 passed`.

### 4.2 Push only Project 03 to GitHub

Go up to the repo root, add **only** the Project 03 files, and push:

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add .gitignore .gitattributes .github/workflows/03-notes-api-ci.yml cloud-pro_3
git status
```

`git status` should list only those files in green. Check that **no** `terraform.tfvars`, `.tfstate` or `.venv` appears. Then:

```bash
git commit -m "feat(03): serverless notes API with Terraform and tests"
git push
```

The first time, a browser window asks you to sign in to GitHub. Approve it.

On GitHub, open your repo → **Actions** tab → **03 Notes API CI**. Wait for both jobs (`test` and `terraform`) to turn green ✅ (about 1–2 minutes).

📸 **`09-github-actions-ci.png`** – the run summary with both jobs green.

Go back into the project folder for the next parts:

```bash
cd cloud-pro_3/03-serverless-notes-api
```

---

## Part 5 – Start KodeKloud and connect VS Code to AWS

⏰ **The 3-hour timer starts now.**

### 5.1 Start the playground and log in to AWS

1. On KodeKloud, open **Playgrounds → AWS** and click **Start**.
2. It shows a **console link, username and password**. Open the link and log in.
3. Check the region in the top right says **N. Virginia (us-east-1)**.

### 5.2 Create access keys for VS Code

1. In the AWS console search bar type **IAM** and open it.
2. Click **Users** → click **your user** (the only one, matching the KodeKloud username).
3. Open the **Security credentials** tab → scroll to **Access keys** → **Create access key**.
4. Choose **Command Line Interface (CLI)** → tick the confirmation box → **Next** → **Create access key**.
5. Click **Download .csv file**. You only see the secret once.

### 5.3 Give the keys to the AWS CLI

In the VS Code terminal:

```bash
aws configure
```

Answer the four questions (to paste in Git Bash: **right-click → Paste** or **Shift + Insert**):

| Question | Type |
|----------|------|
| `AWS Access Key ID [None]:` | the access key from the CSV (starts with `AKIA`) |
| `AWS Secret Access Key [None]:` | the secret from the CSV |
| `Default region name [None]:` | `us-east-1` |
| `Default output format [None]:` | `json` |

Ignore any "Tip: … aws login" message.

### 5.4 Check the connection

```bash
aws sts get-caller-identity
```

You should see `"UserId"`, `"Account"` and `"Arn"`. ✅ You're connected.

---

## Part 6 – Deploy to AWS

### 6.1 Put your name on it

```bash
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
```

In VS Code, open `infrastructure/terraform.tfvars` and change it to:

```hcl
owner = "masegoleroux-commits"
```

Save (`Ctrl + S`). This file stays on your computer only; `.gitignore` keeps it off GitHub.

### 6.2 Deploy

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

Terraform downloads its plugins, checks the code, then builds. Wait for:

```
Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:
api_base_url  = "https://abc123.execute-api.us-east-1.amazonaws.com"
function_name = "notes-api-dev-handler"
table_name    = "notes-api-dev-notes"
```

📸 **`02-terraform-apply.png`** – `Apply complete!` and the outputs.

---

## Part 7 – Check it works and take the screenshots

### 7.1 In the AWS console

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **API Gateway** → APIs → `notes-api-dev-http-api` → **Routes** | The 4 routes: `POST /notes`, `GET /notes`, `GET /notes/{note_id}`, `DELETE /notes/{note_id}` | `03-api-gateway-routes.png` |
| 📸 | **Lambda** → Functions → `notes-api-dev-handler` → **Configuration** → **General configuration** | Memory **128 MB**, Timeout **5 sec** | `04-lambda-config.png` |
| 📸 | **IAM** → Roles → `notes-api-dev-lambda-role` → **Permissions** → click `notes-api-dev-lambda-policy` → **JSON** | The 4 DynamoDB actions on **one** table ARN. **Blur the 12-digit account ID.** | `05-iam-policy.png` |

### 7.2 Smoke test from VS Code

```bash
./scripts/smoke_test.sh
```

You should see:
- **Create**: a note with a long `note_id`
- **List**: `"count": 1`
- **Get one**: the same note
- **Bad request**: `{"error": "title is required"} -> HTTP 400` (this is meant to fail – it proves validation works)
- **Delete**: `HTTP 204`

📸 **`06-smoke-test.png`** – the whole output.

Add one note so the table isn't empty:

```bash
API=$(terraform -chdir=infrastructure output -raw api_base_url)
curl -s -X POST "$API/notes" -H 'Content-Type: application/json' -d '{"title":"Portfolio demo note"}'
```

### 7.3 Data and logs

| # | Where to click | What must be visible | Save as |
|---|----------------|----------------------|---------|
| 📸 | **DynamoDB** → Tables → `notes-api-dev-notes` → **Explore table items** | The "Portfolio demo note" row | `07-dynamodb-items.png` |
| 📸 | **CloudWatch** → Log groups → `/aws/lambda/notes-api-dev-handler` → newest stream → expand a line | JSON lines such as `"message": "note_created"` | `08-cloudwatch-logs.png` |

### Screenshot rules

- Windows: `Win + Shift + S` · Mac: `Cmd + Shift + 4`
- Save as **PNG**, cropped to the useful part.
- **Blur** the account ID, your email and any access keys. Never screenshot the `aws configure` answers.

---

## Part 8 – Tear it all down

Do this before the playground timer ends:

```bash
./scripts/destroy.sh
```

Wait for `Destroy complete! Resources: 13 destroyed.`

📸 **`10-terraform-destroy.png`**

Then deactivate Python: `deactivate`

---

## Part 9 – Diagram, final push, mark complete

### 9.1 Architecture image

In VS Code, open `docs/architecture.drawio` (the Draw.io extension shows the diagram). Use **File → Export** in the diagram editor, choose **PNG**, and save it as:

📸 **`docs/screenshots/00-architecture.png`**

(Or open the file at https://app.diagrams.net and use **File → Export as → PNG**.)

### 9.2 Check you have all 11 images

```bash
ls docs/screenshots/
```

```
00-architecture.png       05-iam-policy.png        09-github-actions-ci.png
01-pytest-pass.png        06-smoke-test.png        10-terraform-destroy.png
02-terraform-apply.png    07-dynamodb-items.png
03-api-gateway-routes.png 08-cloudwatch-logs.png
04-lambda-config.png
```

### 9.3 Write your lessons learned

Open `README.md` in this folder, scroll to **Lessons learned**, and write 3–5 honest bullet points: what broke, how you fixed it, what you'd do differently.

### 9.4 Push the screenshots and README (still only Project 03)

```bash
cd ~/Documents/Discovering-Cloud-Engineering
git add cloud-pro_3
git status          # only cloud-pro_3 files – no tfvars, no tfstate, no .venv
git commit -m "docs(03): add screenshots, diagram and lessons learned"
git push
```

### 9.5 Mark it complete in your main README

Open the **main** `README.md` (repo root). In the Projects table, change project 03's status from `📅 Publishing Mon 12 Oct 2026` to `✅ Complete`. Then:

```bash
git add README.md
git commit -m "docs: mark project 03 complete"
git push
```

Open the project on GitHub: the README now shows your diagram and every screenshot. 🎉

---

## If something goes wrong

| What you see | Why | Fix |
|--------------|-----|-----|
| `chmod: command not found` or `'.' is not recognized` | You're in PowerShell, not Git Bash | Open a new terminal and make sure the dropdown says **Git Bash** |
| `python: command not found` | Python not on PATH | Reinstall Python and tick **Add python.exe to PATH**, then reopen VS Code |
| `No such file or directory: .venv/Scripts/activate` | You're on Mac/Linux | Use `source .venv/bin/activate` |
| `No valid credential sources found` / `ExpiredToken` / `InvalidClientTokenId` | Keys missing or from an old playground | Create new keys (Part 5.2) and run `aws configure` again |
| `No value for required variable "owner"` | `terraform.tfvars` missing or saved as `.txt` | Repeat Part 6.1; the file must be in `infrastructure/` |
| `bad interpreter: /bin/bash^M` | Windows line endings | `sed -i 's/\r$//' scripts/*.sh` |
| `{"message":"Internal Server Error"}` | Lambda permission missing | Run `./scripts/deploy.sh` again |
| HTTP `429` | Throttling (1 request per second) | Wait a few seconds; it's a feature |
| `ProvisionedThroughputExceededException` | More than 1 write per second (sandbox limit) | Slow down |
| Lambda function disappeared | Over 300 calls in an hour (sandbox limit) | Run `./scripts/deploy.sh` again; don't call the API in a loop |
| `git push` rejected: "fetch first" | GitHub has changes you don't | `git pull --rebase` then `git push` |
| Terraform errors about resources "not found" right after starting a **new** playground | Terraform still remembers the old playground's resources | `rm -f infrastructure/terraform.tfstate*` then deploy again |

## Starting again in a new playground

Each playground is a brand-new AWS account. When you start a new one:

1. Create new access keys (Part 5.2) and run `aws configure` (Part 5.3).
2. Delete the old Terraform memory: `rm -f infrastructure/terraform.tfstate infrastructure/terraform.tfstate.backup`
3. Deploy again (Part 6.2).
