#!/usr/bin/env bash
# Live test cases TC-09-L01..L05. Runs commands on the PRIVATE app server through SSM Run
# Command (no SSH, no public IP) and checks its internet traffic leaves through the NAT's
# Elastic IP. Prints PASS/FAIL for each.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
APP_ID=$(terraform output -raw app_instance_id)
NAT_ID=$(terraform output -raw nat_instance_id)
NAT_IP=$(terraform output -raw nat_public_ip)

echo "== Project 09 live test cases: egress"

# TC-09-L01: the app server has no public IP
APP_PUBLIC=$(aws ec2 describe-instances --instance-ids "$APP_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
[ "$APP_PUBLIC" = "None" ] && pass "TC-09-L01 app server has no public IP" || fail "TC-09-L01 app server has public IP $APP_PUBLIC"

# TC-09-L02: the NAT instance has source/destination checking OFF (required to forward traffic)
SDC=$(aws ec2 describe-instance-attribute --instance-id "$NAT_ID" --attribute sourceDestCheck --query 'SourceDestCheck.Value' --output text)
[ "$SDC" = "False" ] && pass "TC-09-L02 NAT source/destination check is off" || fail "TC-09-L02 NAT source/destination check is '$SDC'"

# Commands to run on the server, written to a file so quoting works on Windows too.
# Each line prints "RESULT <name> <value>" so this script can check it.
cat > .ssm-params.json <<'JSON'
{
  "commands": [
    "echo \"RESULT seen_as $(curl -s -m 10 https://checkip.amazonaws.com)\"",
    "echo \"RESULT https $(curl -s -o /dev/null -m 10 -w '%{http_code}' https://aws.amazon.com)\""
  ]
}
JSON
COMMAND_ID=$(aws ssm send-command --instance-ids "$APP_ID" --document-name AWS-RunShellScript \
  --comment "NAT egress test" --parameters file://.ssm-params.json \
  --query 'Command.CommandId' --output text)
rm -f .ssm-params.json

if [ -z "$COMMAND_ID" ]; then
  fail "TC-09-L03 could not reach the app server through SSM (wait 2 more minutes after deploy, then re-run)"
else
  sleep 5
  aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$APP_ID" 2>/dev/null || true
  OUT=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$APP_ID" --query 'StandardOutputContent' --output text)
  SEEN=$(echo "$OUT" | awk '/^RESULT seen_as/{print $3}')
  CODE=$(echo "$OUT" | awk '/^RESULT https/{print $3}')
  pass "TC-09-L03 SSM reached the private server (it registered through the NAT)"
  [ "$SEEN" = "$NAT_IP" ] && pass "TC-09-L04 internet sees the NAT Elastic IP ($NAT_IP)" || fail "TC-09-L04 internet saw '$SEEN', expected $NAT_IP"
  case "$CODE" in 2??|3??) pass "TC-09-L05 HTTPS from the private server works ($CODE)";; *) fail "TC-09-L05 HTTPS from the private server returned '$CODE'";; esac
fi

echo
echo "Result: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
