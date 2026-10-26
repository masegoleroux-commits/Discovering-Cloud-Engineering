#!/usr/bin/env bash
# Live test cases against the deployed project. Prints PASS/FAIL for each.
# Assumes the key-admin and app roles in turn; your own admin user is not used for the checks.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths into C:/Program Files/Git/...
cd "$(dirname "$0")/.."
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
out() { terraform -chdir=infrastructure output -raw "$1"; }

BUCKET=$(out bucket); KEY_ARN=$(out key_arn); TABLE=$(out table); QUEUE=$(out queue_url)
ADMIN_ROLE=$(out key_admin_role_arn); APP_ROLE=$(out app_role_arn)

# as <role arn> <command...>: runs one AWS CLI command with that role's temporary credentials
as() {
  local role="$1"; shift
  local creds
  creds=$(aws sts assume-role --role-arn "$role" --role-session-name kms-test \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text) || return 99
  set -- "$@"
  AWS_ACCESS_KEY_ID=$(echo "$creds" | cut -f1) AWS_SECRET_ACCESS_KEY=$(echo "$creds" | cut -f2) \
  AWS_SESSION_TOKEN=$(echo "$creds" | cut -f3) "$@"
}

echo "== Project 14 live test cases"

# TC-14-L01: objects are encrypted with OUR key by default
ENC=$(aws s3api head-object --bucket "$BUCKET" --key confidential/statement.txt --query '[ServerSideEncryption,SSEKMSKeyId]' --output text)
if echo "$ENC" | grep -q "aws:kms" && echo "$ENC" | grep -q "${KEY_ARN##*/}"; then pass "TC-14-L01 object encrypted with the project key (SSE-KMS)"; else fail "TC-14-L01 object encryption: $ENC"; fi

# TC-14-L02: the app role can read the confidential object
if as "$APP_ROLE" aws s3 cp "s3://$BUCKET/confidential/statement.txt" - >/dev/null 2>&1; then pass "TC-14-L02 app role can read the data"; else fail "TC-14-L02 app role could not read the data"; fi

# TC-14-L03: DELIBERATE TEST - the key admin is refused, even though IAM and S3 allow the read
ERR=$(as "$ADMIN_ROLE" aws s3 cp "s3://$BUCKET/confidential/statement.txt" - 2>&1 >/dev/null)
if echo "$ERR" | grep -qiE "AccessDenied|kms"; then pass "TC-14-L03 key admin refused by the KMS key policy (deliberate test)"; else fail "TC-14-L03 key admin could read the data!"; fi
echo "        error was: $(echo "$ERR" | head -1 | cut -c1-150)"

# TC-14-L04: the key admin CAN still manage the key
if as "$ADMIN_ROLE" aws kms get-key-rotation-status --key-id "$KEY_ARN" --query KeyRotationEnabled --output text 2>/dev/null | grep -q True; then pass "TC-14-L04 key admin can manage the key (rotation status: enabled)"; else fail "TC-14-L04 key admin could not read rotation status"; fi

# TC-14-L05: the key admin can't give themselves a grant
if as "$ADMIN_ROLE" aws kms create-grant --key-id "$KEY_ARN" --grantee-principal "$ADMIN_ROLE" --operations Decrypt >/dev/null 2>&1; then
  fail "TC-14-L05 key admin created a grant (privilege escalation!)"
else pass "TC-14-L05 key admin cannot create a grant for themselves"; fi

# TC-14-L06: the app role writes to the encrypted table and queue
if as "$APP_ROLE" aws dynamodb put-item --table-name "$TABLE" --item '{"record_id":{"S":"test-1"},"note":{"S":"synthetic"}}' >/dev/null 2>&1; then pass "TC-14-L06 app role writes to the KMS-encrypted table"; else fail "TC-14-L06 app role could not write to the table"; fi
if as "$APP_ROLE" aws sqs send-message --queue-url "$QUEUE" --message-body "synthetic test event" >/dev/null 2>&1; then pass "TC-14-L07 app role sends to the KMS-encrypted queue"; else fail "TC-14-L07 app role could not send to the queue"; fi

# TC-14-L08: the table and queue really use the project key
TKEY=$(aws dynamodb describe-table --table-name "$TABLE" --query 'Table.SSEDescription.KMSMasterKeyArn' --output text)
[ "$TKEY" = "$KEY_ARN" ] && pass "TC-14-L08 table encrypted with the project key" || fail "TC-14-L08 table key is $TKEY"

# TC-14-L09 (DELIBERATE TEST): an upload asking for a different encryption type is refused
echo "synthetic" > .test-upload.txt
ERR=$(aws s3api put-object --bucket "$BUCKET" --key confidential/wrong-encryption.txt --body .test-upload.txt \
  --server-side-encryption AES256 2>&1 >/dev/null)
rm -f .test-upload.txt
if echo "$ERR" | grep -q AccessDenied; then pass "TC-14-L09 upload with SSE-S3 instead of the project key is refused (deliberate test)"
else fail "TC-14-L09 upload with another encryption type was not refused"
  aws s3 rm "s3://$BUCKET/confidential/wrong-encryption.txt" >/dev/null 2>&1
fi

echo
echo "Result: $PASSED passed, $FAILED failed"
echo "Decrypt events appear in CloudTrail within about 15 minutes: Event history -> Event source = kms.amazonaws.com"
[ "$FAILED" -eq 0 ]
