#!/usr/bin/env bash
# Live test cases TC-11-L01..L07. Asks DNS questions FROM INSIDE the VPC (via SSM Run
# Command) and checks each answer. Prints PASS/FAIL for each.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
ID=$(terraform output -raw client_instance_id)
ZONE=$(terraform output -raw private_zone)

echo "== Project 11 live test cases (DNS questions asked inside the VPC)"

# Each line prints "RESULT <name> <answer>" so this script can check it.
cat > .ssm-params.json <<JSON
{
  "commands": [
    "echo RESULT private \$(dig +short app.${ZONE} | head -1)",
    "echo RESULT cname \$(dig +short api.${ZONE} | head -1)",
    "echo RESULT public \$(dig +short aws.amazon.com | tail -1)",
    "echo RESULT blocked \$(dig doubleclick.net | grep -o 'status: [A-Z]*' | cut -d' ' -f2)",
    "echo RESULT sinkhole \$(dig +short example.org | tail -1)",
    "echo RESULT alert \$(dig +short example.net | tail -1)"
  ]
}
JSON
COMMAND_ID=$(aws ssm send-command --instance-ids "$ID" --document-name AWS-RunShellScript \
  --comment "DNS firewall tests" --parameters file://.ssm-params.json \
  --query 'Command.CommandId' --output text)
rm -f .ssm-params.json

if [ -z "$COMMAND_ID" ]; then
  fail "TC-11-L01 could not reach the client through SSM (wait 3 minutes after deploy, then re-run)"
else
  sleep 5
  aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$ID" 2>/dev/null || true
  OUT=$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$ID" --query 'StandardOutputContent' --output text)
  val() { echo "$OUT" | awk -v k="$1" '$1=="RESULT" && $2==k {print $3}'; }
  is_ip() { echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; }

  V=$(val private);  is_ip "$V" && [[ "$V" == 10.* ]] && pass "TC-11-L01 app.$ZONE resolves to a private IP ($V)" || fail "TC-11-L01 app.$ZONE answered '$V'"
  V=$(val cname);    [ -n "$V" ] && pass "TC-11-L02 api.$ZONE CNAME resolves ($V)" || fail "TC-11-L02 api.$ZONE did not resolve"
  V=$(val public);   is_ip "$V" && pass "TC-11-L03 public names still resolve (aws.amazon.com -> $V)" || fail "TC-11-L03 aws.amazon.com answered '$V'"
  V=$(val blocked);  [ "$V" = "NXDOMAIN" ] && pass "TC-11-L04 doubleclick.net is BLOCKED (NXDOMAIN)" || fail "TC-11-L04 doubleclick.net status '$V', expected NXDOMAIN"
  V=$(val sinkhole); [ "$V" = "192.0.2.1" ] && pass "TC-11-L05 example.org is SINKHOLED to 192.0.2.1" || fail "TC-11-L05 example.org answered '$V', expected 192.0.2.1"
  V=$(val alert);    is_ip "$V" && pass "TC-11-L06 example.net is ALLOWED but flagged (alert rule) -> $V" || fail "TC-11-L06 example.net answered '$V'"
fi

echo
echo "Result: $PASSED passed, $FAILED failed"
echo "TC-11-M01 (manual): run the saved Logs Insights query 'firewall-hits' to see the ALERT and BLOCK entries."
[ "$FAILED" -eq 0 ]
