# Test Cases: 09 – Private Subnets with a NAT Instance and VPC Flow Logs

Every test case for this project, with an ID that the README and screenshots refer to. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 9 | No | Free | `terraform -chdir=infrastructure test` |
| Live tests (L) | 9 | Yes, after `./scripts/deploy.sh` | under $0.01 | `./scripts/test_egress.sh`, `./scripts/test_rejected.sh` |
| Manual checks (M) | 1 | Yes | Free | Console / inbox (see the guide) |

**Total: 19 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They plan the infrastructure against a mocked AWS and check the security rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-09-T01 | The NAT instance can forward other machines' traffic |
| TC-09-T02 | NAT rules in the start-up script translate only the private subnet |
| TC-09-T03 | The app server is private: no public IP, no inbound rules |
| TC-09-T04 | The private route table sends internet traffic to the NAT, not an internet gateway |
| TC-09-T05 | Both servers are hardened |
| TC-09-T06 | Flow Logs record everything, every minute |
| TC-09-T07 | The NAT host recovers itself |
| TC-09-T08 | Sizes that the free plan blocks are rejected (negative test) |
| TC-09-T09 | The backup size t3.micro gets the x86 image; t4g sizes get the ARM image |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-09-L01 | The app server has no public IP | PublicIpAddress = None | `test_egress.sh` | |
| TC-09-L02 | The NAT instance has source/destination check off | False | `test_egress.sh` | |
| TC-09-L03 | SSM reaches the private server (it registered through the NAT) | Command runs | `test_egress.sh` | |
| TC-09-L04 | The internet sees the NAT's Elastic IP, not the server | checkip = NAT Elastic IP | `test_egress.sh` | |
| TC-09-L05 | HTTPS from the private server works | HTTP 2xx/3xx | `test_egress.sh` | |
| TC-09-L06 | Port 22 on the NAT is closed (deliberate test) | Connection blocked | `test_rejected.sh` | |
| TC-09-L07 | Port 3389 on the NAT is closed (deliberate test) | Connection blocked | `test_rejected.sh` | |
| TC-09-L08 | Port 8080 on the NAT is closed (deliberate test) | Connection blocked | `test_rejected.sh` | |
| TC-09-L09 | Flow Logs record the blocked port-22 attempt | At least one REJECT record | `test_rejected.sh` | |

> **If a port "answers" (L06–L08):** some networks, such as mobile data, offices and antivirus "web shields", run a proxy that answers on ports like 8080 itself, so the knock never reaches AWS. During my build, my phone's mobile data returned `HTTP/1.1 502 Connection timed out` from its own proxy. The script therefore takes its verdict from VPC Flow Logs, AWS's own record: `REJECT` = blocked by AWS (pass), `ACCEPT` = really open (fail), nothing yet = run again in 5 minutes.

## Manual checks

| ID | What to check | Expected | Where | My result |
|----|---------------|----------|-------|-----------|
| TC-09-M01 | The recovery alarm exists and points at the NAT instance | Alarm in OK state with the recover action | manual (guide Part 9) | |
