# Test Cases: 10 – Zero-Internet Workload with VPC Endpoints

Every test case for this project, with an ID that the README and screenshots refer to. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 9 | No | Free | `terraform -chdir=infrastructure test` |
| Live tests (L) | 7 | Yes, after `./scripts/deploy.sh` | under $0.01 | `./scripts/run_tests.sh`, `./scripts/test_from_laptop.sh` |

**Total: 16 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They plan the infrastructure against a mocked AWS and check the security rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-10-T01 | Through the S3 endpoint, only the project's own bucket can be used |
| TC-10-T02 | IAM deliberately allows the outside bucket, so the endpoint policy is what blocks it |
| TC-10-T03 | Confidential objects are refused unless the request comes through the endpoint |
| TC-10-T04 | The DynamoDB endpoint only reaches the events table |
| TC-10-T05 | The three interface endpoints Session Manager needs, with private DNS |
| TC-10-T06 | The workload has no public IP and no route to the internet in its security group |
| TC-10-T07 | Data at rest is protected |
| TC-10-T08 | Sizes the free plan blocks are rejected (negative test) |
| TC-10-T09 | The backup size t3.micro gets the x86 image instead of the ARM one |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-10-L01 | SSM reaches the server through the private interface endpoints | Command runs | `run_tests.sh` | |
| TC-10-L02 | The server can NOT reach the internet | curl fails | `run_tests.sh` | |
| TC-10-L03 | Writes to the data bucket through the S3 gateway endpoint | Upload succeeds | `run_tests.sh` | |
| TC-10-L04 | Reads the file back | Content matches | `run_tests.sh` | |
| TC-10-L05 | A different bucket is blocked by the endpoint policy (deliberate test) | AccessDenied | `run_tests.sh` | |
| TC-10-L06 | Writes and reads DynamoDB through its gateway endpoint | Item read back | `run_tests.sh` | |
| TC-10-L07 | The confidential file can't be read from outside the VPC, even by an admin (deliberate test) | AccessDenied | `test_from_laptop.sh` | |
