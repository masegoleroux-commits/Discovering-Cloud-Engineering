# Findings: Security Baseline Audit

What the baseline found in my AWS account, how I checked projects 03–06 against the same rules, and the results of the deliberate tests.

There are three kinds of evidence here, and I keep them separate:

1. **Real findings:** something AWS Config or an alarm actually flagged.
2. **Code review:** what my Terraform says about each rule. Useful, but it's what I *expect*, not what Config *saw*.
3. **Deliberate tests:** problems I created on purpose to prove the controls work.

---

## 1. Real findings

<!-- Only add a row for something Config or an alarm actually flagged. Check AWS Config → Rules after deploying (Part 6), before the deliberate test. -->

| Date | Rule or alarm | Resource | Project | Root cause | Fix |
|------|---------------|----------|---------|------------|-----|
| 15 Oct 2026 | <!-- e.g. iam-password-policy --> | <!-- e.g. the account --> | <!-- e.g. account-wide --> | <!-- why --> | <!-- what you did --> |

### Likely real finding: `iam-password-policy`

Check this one first. The AWS managed rule expects a strong account password policy (by default: minimum length 14, upper and lower case, a number, a symbol, no reuse of the last 24 passwords, change every 90 days). A new account usually has **no custom policy**, so the rule shows **Noncompliant** on day one.

**Only if Config shows it as Noncompliant**, record it like this:

| Date | Rule or alarm | Resource | Project | Root cause | Fix |
|------|---------------|----------|---------|------------|-----|
| 15 Oct 2026 | `iam-password-policy` | The AWS account | Account-wide | No custom IAM password policy had been set, so the account used AWS's weak default. | Set a policy matching the rule (command below); the rule returned to Compliant on its next evaluation. |

Fix command (it changes your account's password policy, and only affects your admin user's **next** password change):

```bash
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-uppercase-characters --require-lowercase-characters \
  --require-numbers --require-symbols \
  --password-reuse-prevention 24 --max-password-age 90 \
  --allow-users-to-change-password
```

Then **AWS Config → Rules → `iam-password-policy` → Actions → Re-evaluate**.

### Another possible real finding: the "unauthorised API calls" alarm

This alarm counts **every** `AccessDenied`, not just the deliberate test. In my account, the organisation's policy (SCP) blocks every region except eu-north-1, so any tool or script still pointed at `us-east-1` triggers it. **If you got an alarm email you didn't cause on purpose**, open **CloudWatch → Log groups → `/security-baseline-dev/cloudtrail`** and search for `AccessDenied`. Record the `eventName`, `awsRegion` and `userIdentity` of what you find.

| Date | Rule or alarm | Resource | Project | Root cause | Fix |
|------|---------------|----------|---------|------------|-----|
| <!-- --> | `unauthorized-api-calls` alarm | <!-- e.g. ec2:DescribeInstances in us-east-1 --> | <!-- --> | <!-- e.g. CLI default region wrong / old script --> | <!-- e.g. set region to eu-north-1 --> |

---

## 2. Code review: projects 03–06 against the six rules

**Method:** I read each project's Terraform and checked it against each Config rule. **These are expectations from the code, not Config results.** Projects 03–06 had already been destroyed when the baseline ran, so Config never saw them. To turn a row into real evidence, redeploy that project while the baseline runs (START-HERE Part 10).

| Rule | 03 Notes API | 04 Web server | 05 ECS Fargate | 06 CSV pipeline |
|------|--------------|---------------|----------------|-----------------|
| `restricted-ssh` (no SSH open to the world) | No security groups (serverless) | ✅ Only port 80 open; SSH rule exists only if `enable_ssh_fallback = true`, and then only from my own IP | ✅ ALB allows port 80; tasks only accept traffic from the ALB's security group | No security groups (serverless) |
| `ec2-imdsv2-check` | No EC2 | ✅ `http_tokens = "required"` | No EC2 (Fargate) | No EC2 |
| `encrypted-volumes` | No EBS | ✅ Root volume `encrypted = true` | No EBS (Fargate storage is managed by AWS) | No EBS |
| `s3-bucket-public-read-prohibited` | No S3 | No S3 | No S3 (images are in ECR) | ✅ Public access block: all four settings on |
| `s3-bucket-server-side-encryption-enabled` | No S3 (DynamoDB is encrypted at rest) | No S3 | No S3 | ✅ SSE-S3 default encryption |
| `iam-password-policy` | Account-wide (see section 1) | ← | ← | ← |

**What the review showed:**
- Nothing in projects 03–06 is expected to fail these rules, because the hardening was built in from the start: IMDSv2, encrypted disks, no SSH, and S3 public access blocks.
- **Project 01 would fail `s3-bucket-public-read-prohibited`, by design.** A static website bucket has to be publicly readable. In a real company I'd put CloudFront in front with a private bucket (Project 12 covers that pattern) or add a documented exception for that one bucket.
- **Gap the rules don't cover:** Project 05's tasks allow outbound traffic to `0.0.0.0/0`, so they can pull images from ECR without a NAT or VPC endpoints. None of the six rules checks outbound rules. Project 10 shows how VPC endpoints would remove that need.

---

## 3. Deliberate tests (not real findings)

Created with `./scripts/create_test_violations.sh` on purpose, to prove the controls work, then removed with `./scripts/cleanup_test_violations.sh`.

<!-- Fill in "What happened" with what you actually saw: the status, and roughly how many minutes it took. -->

| Date | Test | Expected result | What happened |
|------|------|-----------------|---------------|
| 15 Oct 2026 | Open-SSH security group | `restricted-ssh` NON_COMPLIANT, SG-change alarm | <!-- e.g. Noncompliant after ~N min; alarm email after ~N min (it went to junk at first) --> |
| 15 Oct 2026 | Instance allowing IMDSv1 (Amazon Linux 2023, `HttpTokens=optional`) | `ec2-imdsv2-check` NON_COMPLIANT | <!-- --> |
| 15 Oct 2026 | Unencrypted attached volume | `encrypted-volumes` NON_COMPLIANT | <!-- If it stayed Compliant: "EBS encryption by default is on in this account, so the volume was encrypted anyway – the account-level setting prevents the violation." --> |
| 15 Oct 2026 | Denied API call from a role with no permissions | Unauthorised-calls alarm | <!-- --> |
| 15 Oct 2026 | Cleanup | Rules return to Compliant, or the deleted resources drop off | <!-- --> |

### Problems while running the tests

| What I saw | Cause | Fix |
|------------|-------|-----|
| `ParameterNotFound` when the test script looked up the server image | It asked Systems Manager for Canonical's Ubuntu image ID, and that lookup failed in eu-north-1 | Switched to Amazon Linux 2023, which AWS publishes in every region, with a fallback lookup. The script now stops before creating anything if no image is found. |