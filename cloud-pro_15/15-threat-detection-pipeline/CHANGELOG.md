# Changelog – 15 Threat Detection Pipeline

Newest first. Dates are when the change was made; deployment results are recorded in the README.

## 2026-11-09 – Live test fix, part 2: the log search itself failed
- **What I saw:** after the fix below, L04 still failed ("no alert yet"), although the email arrived and the diagnosis showed `MatchedEvents: 1.0`, `Invocations: 2.0` and the formatter's `[DELIBERATE TEST]` log line.
- **Cause:** the check piped the AWS CLI straight into `grep -q`, and the script uses `set -o pipefail`. `grep -q` stops at the first match, so the CLI was cut off while still printing pages (exit 141). pipefail then counted the whole check as failed.
- **Fix:** L04 and L05 now save the CLI output first and search it afterwards.
- **Lesson:** under `set -o pipefail`, `command | grep -q` can fail even when the text is there. Save the output first, or don't use `-q`.

## 2026-11-09 – Live test fix, part 1: TC-15-L04 missed a real alert
- **Problem:** L04 failed, but the diagnosis showed the pipeline worked: EventBridge matched 1 event and made 2 invocations with no failures, and the formatter logged the `[DELIBERATE TEST]` subject after publishing.
- **Cause:** the script searched with a CloudWatch Logs filter pattern for "DELIBERATE TEST", which didn't match even though the line was in the log.
- **Fix:** L04 now reads the formatter's recent log lines and searches them itself, the same way the diagnosis does.

## 2026-11-09 – Tidy-up
- Added this changelog.
- Removed two leftover decision records from the GuardDuty design (`docs/adr/0002-severity-filter.md`, `docs/adr/0003-sample-findings.md`); they were replaced on 27 October and contradicted the current design.

## 2026-10-27 – Detection fix: the short CLI form was missed
- **Problem:** live tests TC-15-L04 and L05 failed: no alert and no tag.
- **Cause:** CloudTrail records `aws ec2 authorize-security-group-ingress --protocol tcp --port 22 --cidr 0.0.0.0/0` as flat fields (`cidrIp`, `fromPort`, …). Both Lambdas only read the nested `ipPermissions.items` form, so they skipped the event.
- **Fix:** both Lambdas now read both forms. Skipped events are logged together with what was received.
- New unit test **TC-15-U14** (14 unit tests in total).
- `run_tests.sh` now prints a diagnosis when L04 or L05 fail: EventBridge's matched, invoked and failed counts, and each Lambda's last log lines.
- Fixed the query used by TC-15-L06, which returned 0 instead of 1.

## 2026-10-27 – Redesigned around CloudTrail
- **Why:** deploying failed with `explicit deny in a service control policy` for both GuardDuty and Security Hub. See [ADR 0003](docs/adr/0003-cloudtrail-instead-of-guardduty.md).
- **New:**
  - A single-region CloudTrail trail with log file validation, writing to a private, encrypted S3 bucket that expires logs after 1 day. `create_trail = false` reuses an existing trail.
  - Three EventBridge rules: an inbound security-group rule, `StopLogging`/`DeleteTrail`, and `DeleteBucketPublicAccessBlock`.
  - A harmless test VPC and security group, attached to nothing, for the deliberate test.
- **Changed:**
  - The formatter writes CloudTrail-based alerts: severity, who, from which IP, and what to do.
  - Alerts about the test group are labelled `[DELIBERATE TEST]`.
  - The responder only tags security groups, with the `SecurityFinding` key.
- **Removed:** GuardDuty, Security Hub, and the `create_detector`, `enable_security_hub` and `min_severity` variables.
- **Added input checks:**
  - `aws_region` refuses an Availability Zone such as `eu-north-1b`.
  - `alert_email` must be an email address.
- **Tests:** 10 offline Terraform tests (T01–T10), 13 unit tests, and 7 live tests that run a deliberate test opening and closing port 22 on the test group.
- **Docs:** README, guide, architecture, runbook, test cases and the ADRs rewritten.
  - ADR 0002 is now "decide 'open to the internet' in code".
  - ADR 0003 is now "CloudTrail instead of GuardDuty".

## 2026-10-22 – Terraform test fix
- Offline tests now use `command = apply` with the mock provider. In a plan run, Terraform leaves the role's policy unknown, which made assertions fail. Tests that only check that bad input is refused stay as `command = plan`.

## 2026-10-17 – First version
- GuardDuty and Security Hub design with formatter and responder Lambdas, offline Terraform tests, unit tests and a live test script.
