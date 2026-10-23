# Test Cases: 13 – Automatic Secret Rotation with AWS Secrets Manager

Every test case for this project, with an ID that the README and screenshots refer to. Deliberate tests are labelled: they create a problem on purpose to prove a control works.

| Level | Cases | Needs AWS? | Cost | How to run |
|-------|-------|------------|------|------------|
| Offline Terraform tests (T) | 8 | No | Free | `terraform -chdir=infrastructure test` |
| Unit tests (U) | 13 | No (AWS is mocked) | Free | `pytest -v` |
| Live tests (L) | 9 | Yes, after `./scripts/deploy.sh` | under $0.01 | `./scripts/run_tests.sh` |
| Manual checks (M) | 1 | Yes | Free | Console / inbox (see the guide) |

**Total: 31 test cases.** Offline and unit tests also run in GitHub Actions on every push.

## Offline Terraform tests

They plan the infrastructure against a mocked AWS and check the security rules in the code, so a broken rule fails before anything is deployed. Negative tests (marked *rejects*) prove bad input is refused.

| ID | What it proves |
|----|----------------|
| TC-13-T01 | Rotation runs on a schedule, but not immediately on deploy |
| TC-13-T02 | Only Secrets Manager, for this one secret, can run the rotation function |
| TC-13-T03 | The client can only READ the secret: it can never change or rotate it |
| TC-13-T04 | The API can only read the registry |
| TC-13-T05 | No function has a wildcard action, and "*" resources appear only where AWS requires it |
| TC-13-T06 | The registry is encrypted and the secret is deleted immediately on teardown |
| TC-13-T07 | The registry stores a hash of the first key, never the key itself |
| TC-13-T08 | An invalid rotation interval is rejected (negative test) |

## Unit tests

The Python code is tested with a fake AWS (moto or botocore Stubber), so they run in seconds and cost nothing.

| ID | What it proves |
|----|----------------|
| TC-13-U01 | CreateSecret stores a NEW 40-character key as AWSPENDING |
| TC-13-U02 | A retried createSecret does not generate a second, different key |
| TC-13-U03 | SetSecret registers only the SHA-256 hash of the new key |
| TC-13-U04 | If the API rejects the new key, rotation stops and the old key stays current |
| TC-13-U05 | After one rotation the new key is current AND the old key still works |
| TC-13-U06 | After two rotations, the first key is revoked; only current and previous work |
| TC-13-U07 | An unknown step name is refused |
| TC-13-U08 | The function refuses to run for a secret that doesn't have rotation enabled |
| TC-13-U09 | A registered key gets 200 and the key's version |
| TC-13-U10 | An unknown key gets 403 |
| TC-13-U11 | A request with no key gets 400 |
| TC-13-U12 | The client reads the secret once, then uses its cache |
| TC-13-U13 | If the cached key is rejected, the client re-reads the secret and succeeds |

## Live tests

Run against the real deployment. Each prints `PASS` or `FAIL`, and the script exits non-zero if anything fails. Record your own result and date in the last column; leave it empty until you have actually run it.

| ID | What it proves | Expected | Script | My result |
|----|----------------|----------|--------|-----------|
| TC-13-L01 | The client app works with the first key | HTTP 200 | `run_tests.sh` | |
| TC-13-L02 | A rotation completes all four steps | New version becomes AWSCURRENT | `run_tests.sh` | |
| TC-13-L03 | The key value changed | Different key | `run_tests.sh` | |
| TC-13-L04 | The previous key still works (cached clients don't break) | HTTP 200 | `run_tests.sh` | |
| TC-13-L05 | The client keeps working straight after a rotation | HTTP 200 | `run_tests.sh` | |
| TC-13-L06 | After a second rotation, the key from two rotations ago is revoked | HTTP 403 | `run_tests.sh` | |
| TC-13-L07 | The previous key (rotation 1) is still accepted | HTTP 200 | `run_tests.sh` | |
| TC-13-L08 | A made-up key is refused | HTTP 403 | `run_tests.sh` | |
| TC-13-L09 | The registry holds hashes, never a usable key | Plain key not found | `run_tests.sh` | |

## Manual checks

| ID | What to check | Expected | Where | My result |
|----|---------------|----------|-------|-----------|
| TC-13-M01 | CloudTrail shows the RotateSecret events | Events in Event history | manual (console) | |
