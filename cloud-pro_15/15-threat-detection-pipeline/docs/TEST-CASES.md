# Test Cases: 15 – Threat Detection Pipeline with CloudTrail and EventBridge

Every test case for this project, with an ID that the README and screenshots refer to. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 10 | No | Free | `terraform -chdir=infrastructure test` |
| Unit tests (U) | 14 | No (AWS is mocked) | Free | `python -m pytest -v` |
| Live tests (L) | 7 | Yes, after `./scripts/deploy.sh` | Free | `./scripts/run_tests.sh` |
| Manual checks (M) | 1 | Yes | Free | Your inbox |

**Total: 32 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They apply the infrastructure against a mocked AWS and check the rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-15-T01 | The security-group rule watches every new inbound rule (`AuthorizeSecurityGroupIngress`) from EC2 |
| TC-15-T02 | Stopping or deleting a trail, and removing a bucket's Block Public Access, are watched too; every rule reads CloudTrail API-call events |
| TC-15-T03 | Every rule reaches both functions (6 targets), and only EventBridge may invoke them |
| TC-15-T04 | The responder may only add the `SecurityFinding` tag to security groups: nothing destructive |
| TC-15-T05 | The formatter may only publish to this project's topic, and knows the test group so test alerts are labelled |
| TC-15-T06 | The trail is single-region with log file validation, and its bucket is private and encrypted |
| TC-15-T07 | With `create_trail = false`, no second trail or bucket is created |
| TC-15-T08 | The test security group starts with no inbound rules and is labelled `deliberate-test` |
| TC-15-T09 | An Availability Zone typed as the region is refused (negative test) |
| TC-15-T10 | A bad email address is refused (negative test) |

## Unit tests

They run the Lambda code against events shaped like real CloudTrail records, with AWS mocked by moto.

| ID | What it proves |
|----|----------------|
| TC-15-U01 | Port 22 opened to 0.0.0.0/0 is HIGH, and the email names the port, the group, who did it and from which IP |
| TC-15-U02 | "All traffic" is CRITICAL, and IPv6 `::/0` and port ranges are reported too |
| TC-15-U03 | `StopLogging` and `DeleteTrail` are CRITICAL and name the trail |
| TC-15-U04 | Removing a bucket's Block Public Access is HIGH and names the bucket |
| TC-15-U05 | Alerts about the test group say DELIBERATE TEST; failed calls are LOW and say nothing changed |
| TC-15-U06 | A very long name is cut so the subject stays within 100 characters |
| TC-15-U07 | The handler publishes exactly one message to the topic |
| TC-15-U08 | A new rule from a private range sends no email; one open to the internet does |
| TC-15-U09 | A group opened to the internet gets the `SecurityFinding` tag, and the rule is **not** removed |
| TC-15-U10 | `::/0` counts as open to the internet |
| TC-15-U11 | A call that failed (for example AccessDenied) makes no AWS call at all |
| TC-15-U12 | A rule from a private range is left alone by the responder |
| TC-15-U13 | Trail and bucket events are reported by email but never acted on automatically |
| TC-15-U14 | The flat form CloudTrail records for the short CLI command (`--protocol tcp --port 22 --cidr 0.0.0.0/0`) is detected by both functions |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-15-L01 | A CloudTrail trail is logging | `IsLogging = True` | `run_tests.sh` | |
| TC-15-L02 | All 3 detection rules are enabled | `ENABLED` | `run_tests.sh` | |
| TC-15-L03 | Deliberate test: port 22 opened to 0.0.0.0/0 on the harmless test group | Rule added | `run_tests.sh` | |
| TC-15-L04 | The formatter sends a `[DELIBERATE TEST]` alert | Log line within ~15 minutes | `run_tests.sh` | |
| TC-15-L05 | The responder tags the test group with `SecurityFinding` | Tag present | `run_tests.sh` | |
| TC-15-L06 | The responder left the rule in place (tag only) | Rule still there before clean-up | `run_tests.sh` | |
| TC-15-L07 | The script closes the port again | No inbound rules | `run_tests.sh` | |

## Manual checks

| ID | What to check | Expected | Where | My result |
|----|---------------|----------|-------|-----------|
| TC-15-M01 | The alert email arrives | Email `[DELIBERATE TEST] HIGH: AuthorizeSecurityGroupIngress sg-...` (check junk) | Inbox | |
