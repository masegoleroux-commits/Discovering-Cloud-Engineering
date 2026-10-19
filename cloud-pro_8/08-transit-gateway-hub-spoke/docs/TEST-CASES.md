# Test Cases: 08 – Hub-and-Spoke Network with AWS Transit Gateway

Every test case for this project, with an ID you can quote in interviews and in the README. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 8 | No | Free | `terraform -chdir=infrastructure test` |
| Live tests (L) | 3 | Yes, after `./scripts/deploy.sh` | about $0.30 per run (3 analyses) | `./scripts/run_analysis.sh` |
| Manual checks (M) | 1 | Yes | Free | Console / inbox (see the guide) |

**Total: 12 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They plan the infrastructure against a mocked AWS and check the security rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-08-T01 | The Transit Gateway never auto-joins attachments to a route table |
| TC-08-T02 | By default, spokes learn ONLY the shared route (app <-> data blocked) |
| TC-08-T03 | The shared route table learns both spokes |
| TC-08-T04 | Flipping the switch opens app <-> data |
| TC-08-T05 | Two subnets per VPC, each in a different AZ |
| TC-08-T06 | Probe security groups never allow traffic from the internet |
| TC-08-T07 | The three reachability questions exist |
| TC-08-T08 | A VPC map missing a role is rejected (negative test) |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-08-L01 | app VPC can reach the shared VPC on TCP 443 | Reachable = True | `run_analysis.sh` | |
| TC-08-L02 | data VPC can reach the shared VPC on TCP 443 | Reachable = True | `run_analysis.sh` | |
| TC-08-L03 | app VPC can NOT reach the data VPC (segmentation) | Reachable = False, with AWS's explanation (True after the switch is flipped) | `run_analysis.sh` | |

## Manual checks

| ID | What to check | Expected | Where | My result |
|----|---------------|----------|-------|-----------|
| TC-08-M01 | Flipping `allow_app_to_data` opens the path, and flipping it back closes it | Re-run shows L03 True, then False again | manual (guide Part 8) | |
