# Test Cases: 12 – Highly Available Web Tier behind CloudFront and AWS WAF

Every test case for this project, with an ID that the README and screenshots refer to. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 10 | No | Free | `terraform -chdir=infrastructure test` |
| Live tests (L) | 7 | Yes, after `./scripts/deploy.sh` | under $0.01 | `./scripts/test_access.sh`, `./scripts/test_rate_limit.sh`, `./scripts/test_self_healing.sh` |

**Total: 17 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They plan the infrastructure against a mocked AWS and check the security rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-12-T01 | By default WAF is regional, attached to the ALB, and nothing is created in us-east-1 |
| TC-12-T02 | With CloudFront on, the ALB only accepts CloudFront's addresses |
| TC-12-T03 | Requests without the secret header get a 403; with it, they're forwarded |
| TC-12-T04 | The web servers are only reachable from the ALB and only talk to S3 |
| TC-12-T05 | High availability: at least 2 servers across 2 AZs, replaced on failed health checks |
| TC-12-T06 | The load balancer drops malformed headers |
| TC-12-T07 | Without CloudFront, the ALB becomes the public entry (still behind WAF) |
| TC-12-T08 | Sizes the free plan blocks are rejected (negative test) |
| TC-12-T09 | An unknown WAF scope is rejected (negative test) |
| TC-12-T10 | The backup size t3.micro gets the x86 image, and `az_index = 1` moves the servers to eu-north-1b and 1c |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-12-L01 | The site answers through its front door | HTTP 200 | `test_access.sh` | |
| TC-12-L02 | Servers in both Availability Zones answer | 2 zones in /whoami | `test_access.sh` | |
| TC-12-L03 | Visitors use HTTPS (CloudFront on) | https:// URL | `test_access.sh` | |
| TC-12-L04 | Going around CloudFront to the load balancer is refused | No answer or 403 | `test_access.sh` | |
| TC-12-L05 | WAF rate limit blocks a flood of requests (deliberate test) | Some 403s | `test_rate_limit.sh` | |
| TC-12-L06 | No failed requests while a server is terminated (deliberate test) | 0 errors | `test_self_healing.sh` | |
| TC-12-L07 | Auto Scaling replaces the terminated server | Back to desired capacity | `test_self_healing.sh` | |
