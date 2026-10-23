#!/usr/bin/env bash
# Live test cases TC-10-L01..L06. Runs the tests ON the private instance through SSM Run
# Command (over the private endpoints) and checks each result. Prints PASS/FAIL for each.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
REGION=$(aws configure get region 2>/dev/null || true); REGION=${REGION:-eu-north-1}
ID=$(terraform output -raw instance_id)
DATA=$(terraform output -raw data_bucket)
OUTSIDE=$(terraform output -raw outside_bucket)
TABLE=$(terraform output -raw events_table)

echo "== Project 10 live test cases (run on the private server)"

# Each command prints "RESULT <test> <ok|BAD>" so this script can check it.
# Variables are filled in here; everything else runs on the instance.
cat > .ssm-params.json <<JSON
{
  "commands": [
    "curl -s -m 5 -o /dev/null https://example.com && echo 'RESULT internet BAD' || echo 'RESULT internet ok'",
    "echo 'Quarterly figures (synthetic)' | aws s3 cp - s3://${DATA}/confidential/report.txt --region ${REGION} >/dev/null && echo 'RESULT s3write ok' || echo 'RESULT s3write BAD'",
    "aws s3 cp s3://${DATA}/confidential/report.txt - --region ${REGION} | grep -q Quarterly && echo 'RESULT s3read ok' || echo 'RESULT s3read BAD'",
    "aws s3api get-object --bucket ${OUTSIDE} --key hello.txt /tmp/hello.txt --region ${REGION} 2>&1 | grep -q AccessDenied && echo 'RESULT outside ok' || echo 'RESULT outside BAD'",
    "aws dynamodb put-item --table-name ${TABLE} --item '{\"event_id\": {\"S\": \"test-1\"}}' --region ${REGION} && aws dynamodb get-item --table-name ${TABLE} --key '{\"event_id\": {\"S\": \"test-1\"}}' --query Item.event_id.S --output text --region ${REGION} | grep -q test-1 && echo 'RESULT dynamodb ok' || echo 'RESULT dynamodb BAD'"
  ]
}
JSON
COMMAND_ID=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --comment "Zero-internet tests" --parameters file://.ssm-params.json \
  --query 'Command.CommandId' --output text)
rm -f .ssm-params.json

if [ -z "$COMMAND_ID" ]; then
  fail "TC-10-L01 could not reach the server through the SSM endpoints (wait 3-5 minutes after deploy, then re-run)"
else
  pass "TC-10-L01 SSM reached the server through the private interface endpoints"
  sleep 5
  aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$ID" 2>/dev/null || true
  OUT=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$ID" --query 'StandardOutputContent' --output text)
  check() {  # check <result name> <test id + description>
    if echo "$OUT" | grep -q "^RESULT $1 ok"; then pass "$2"; else fail "$2"; fi
  }
  check internet "TC-10-L02 the server can NOT reach the internet"
  check s3write  "TC-10-L03 writes to the data bucket through the S3 gateway endpoint"
  check s3read   "TC-10-L04 reads it back"
  check outside  "TC-10-L05 a DIFFERENT bucket is blocked by the endpoint policy (AccessDenied)"
  check dynamodb "TC-10-L06 writes and reads DynamoDB through its gateway endpoint"
fi

echo
echo "Result: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
