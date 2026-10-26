# Test Cases: 14 – KMS Encryption and Key Policies

Every test case for this project, with an ID that the README and screenshots refer to. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 8 | No | Free | `terraform -chdir=infrastructure test` |
| Live tests (L) | 9 | Yes, after `./scripts/deploy.sh` | under $0.01 | `./scripts/run_tests.sh` |

**Total: 17 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They plan the infrastructure against a mocked AWS and check the security rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-14-T01 | Key admins can manage the key but have NO action that reads or encrypts data |
| TC-14-T02 | Admins can't give themselves access (no CreateGrant, no PutKeyPolicy, no Create*) |
| TC-14-T03 | The app role can use the key and nothing else |
| TC-14-T04 | The key rotates yearly and can't be deleted in one step |
| TC-14-T05 | S3, DynamoDB and SQS all use THIS key |
| TC-14-T06 | The deliberate test is valid: IAM DOES allow the admin to read the object |
| TC-14-T07 | A deletion window AWS doesn't allow is rejected (negative test) |
| TC-14-T08 | The bucket refuses uploads under another encryption type or key, and plain HTTP |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-14-L01 | Objects are encrypted with the project key by default | SSE-KMS with our key | `run_tests.sh` | |
| TC-14-L02 | The app role can read the confidential object | Read succeeds | `run_tests.sh` | |
| TC-14-L03 | The key admin is refused by the key policy (deliberate test) | AccessDenied from KMS | `run_tests.sh` | |
| TC-14-L04 | The key admin CAN still manage the key | Rotation status readable | `run_tests.sh` | |
| TC-14-L05 | The key admin can't give themselves a grant | AccessDenied | `run_tests.sh` | |
| TC-14-L06 | The app role writes to the encrypted table | Put succeeds | `run_tests.sh` | |
| TC-14-L07 | The app role sends to the encrypted queue | Send succeeds | `run_tests.sh` | |
| TC-14-L08 | The table really uses the project key | KMSMasterKeyArn = our key | `run_tests.sh` | |
| TC-14-L09 | An upload asking for SSE-S3 instead of the project key is refused (deliberate test) | AccessDenied | `run_tests.sh` | |
