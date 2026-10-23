# Test Cases: 11 – Private DNS and Route 53 Resolver DNS Firewall

Every test case for this project, with an ID that the README and screenshots refer to. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 7 | No | Free | `terraform -chdir=infrastructure test` |
| Live tests (L) | 7 | Yes, after `./scripts/deploy.sh` | under $0.01 | `./scripts/test_dns.sh`, `./scripts/test_from_laptop.sh` |
| Manual checks (M) | 1 | Yes | Free | Console / inbox (see the guide) |

**Total: 15 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They plan the infrastructure against a mocked AWS and check the security rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-11-T01 | The zone is private (attached to the VPC), not public |
| TC-11-T02 | The three firewall actions, in the right order |
| TC-11-T03 | The sinkhole points at a reserved documentation address, never a real server |
| TC-11-T04 | Every DNS question in the VPC is logged |
| TC-11-T05 | The test client has a Free Tier size and IMDSv2 |
| TC-11-T06 | A zone name that could clash with the internet is rejected (negative test) |
| TC-11-T07 | A domain without its trailing dot is rejected (negative test) |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-11-L01 | `app.corp.internal` resolves inside the VPC | A 10.x address | `test_dns.sh` | |
| TC-11-L02 | `api.corp.internal` (CNAME) resolves | app.corp.internal | `test_dns.sh` | |
| TC-11-L03 | Public names still resolve | An IP address | `test_dns.sh` | |
| TC-11-L04 | A blocked domain gets NXDOMAIN | NXDOMAIN | `test_dns.sh` | |
| TC-11-L05 | A sinkholed domain is redirected | 192.0.2.1 | `test_dns.sh` | |
| TC-11-L06 | An alert-only domain still resolves | An IP address (and a log entry) | `test_dns.sh` | |
| TC-11-L07 | The private zone does NOT resolve outside the VPC | No 10.x answer | `test_from_laptop.sh` | |

## Manual checks

| ID | What to check | Expected | Where | My result |
|----|---------------|----------|-------|-----------|
| TC-11-M01 | Query logs show the BLOCK and ALERT hits | Rows in the firewall-hits saved query | manual (Logs Insights) | |
