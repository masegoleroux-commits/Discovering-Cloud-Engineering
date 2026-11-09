#!/usr/bin/env bash
# Live test cases (DELIBERATE TEST). Opens port 22 to the whole internet on the project's
# harmless test security group (it is attached to nothing, in an empty VPC), checks that
# the alert and the tag arrive, then closes the port again - even if the script is stopped.
# CloudTrail events usually reach EventBridge within a few minutes; this waits up to 15.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (like /aws/lambda/...) into Windows paths
cd "$(dirname "$0")/.."
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
out() { terraform -chdir=infrastructure output -raw "$1"; }

SG=$(out test_security_group_id)
TRAIL=$(out trail_name)
FMT_LOGS=$(out formatter_log_group)
RESP_LOGS=$(out responder_log_group)
RULES=$(terraform -chdir=infrastructure output -json rule_names | tr -d '[]"' | tr ',' ' ')
START_MS=$(( $(date +%s) * 1000 ))

close_port() {   # always runs: removes the deliberate test rule
  aws ec2 revoke-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr 0.0.0.0/0 >/dev/null 2>&1 \
    && echo "  (deliberate test rule removed from $SG)"
}
trap close_port EXIT

echo "== Project 15 live test cases"

# TC-15-L01: a CloudTrail trail is logging (EventBridge gets nothing without one)
if [ -n "$TRAIL" ]; then
  [ "$(aws cloudtrail get-trail-status --name "$TRAIL" --query IsLogging --output text 2>/dev/null)" = "True" ] \
    && pass "TC-15-L01 trail $TRAIL is logging" || fail "TC-15-L01 trail $TRAIL is not logging"
else
  N=$(aws cloudtrail describe-trails --query "length(trailList)" --output text 2>/dev/null)
  [ "${N:-0}" -gt 0 ] 2>/dev/null && pass "TC-15-L01 using an existing trail (create_trail = false)" || fail "TC-15-L01 no trail found: set create_trail = true"
fi

# TC-15-L02: all three rules are enabled
bad=""
for r in $RULES; do
  [ "$(aws events describe-rule --name "$r" --query State --output text 2>/dev/null)" = "ENABLED" ] || bad="$bad $r"
done
[ -z "$bad" ] && pass "TC-15-L02 all 3 detection rules are enabled" || fail "TC-15-L02 rules not enabled:$bad"

# TC-15-L03 (DELIBERATE TEST): open port 22 to the internet on the harmless test group
if aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 --cidr 0.0.0.0/0 >/dev/null; then
  pass "TC-15-L03 deliberate test: port 22 opened to 0.0.0.0/0 on test group $SG (attached to nothing)"
else
  fail "TC-15-L03 could not add the test rule to $SG"
fi

# TC-15-L04 / L05: the alert and the tag arrive
echo "  ...waiting up to 15 minutes for CloudTrail -> EventBridge -> both functions"
seen_fmt=""; tagged=""
for _ in $(seq 1 45); do
  # Read the formatter's recent log lines and look for the label ourselves. (A CloudWatch
  # filter pattern for "DELIBERATE TEST" didn't match during my build, even though the
  # line was there, so the search isn't left to CloudWatch.)
  # Save the CLI output first, then search it. Piping straight into "grep -q" fails under
  # "set -o pipefail": grep stops at the first match, the CLI is cut off while it is still
  # printing more pages, and the whole pipe counts as failed even though the text was found.
  if [ -z "$seen_fmt" ]; then
    msgs=$(aws logs filter-log-events --log-group-name "$FMT_LOGS" --start-time "$START_MS" \
      --query 'events[].message' --output text 2>/dev/null || true)
    case "$msgs" in *"DELIBERATE TEST"*) seen_fmt=1 ;; esac
  fi
  if [ -z "$tagged" ]; then
    tag=$(aws ec2 describe-security-groups --group-ids "$SG" \
      --query "SecurityGroups[0].Tags[?Key=='SecurityFinding'].Value | [0]" --output text 2>/dev/null || true)
    case "$tag" in *"open-to-internet"*) tagged=1 ;; esac
  fi
  [ -n "$seen_fmt" ] && [ -n "$tagged" ] && break
  sleep 20
done
[ -n "$seen_fmt" ] && pass "TC-15-L04 formatter sent a [DELIBERATE TEST] alert" || fail "TC-15-L04 no alert yet (CloudTrail can lag; re-run in a few minutes)"
[ -n "$tagged" ] && pass "TC-15-L05 responder tagged $SG with SecurityFinding" || fail "TC-15-L05 the test group wasn't tagged in time"

# If either failed, show where the event stopped: EventBridge's counters and each function's last log lines
if [ -z "$seen_fmt" ] || [ -z "$tagged" ]; then
  echo "  ---- diagnosis: where did the event stop?"
  RULE=$(echo "$RULES" | tr ' ' '\n' | grep sg-open-to-internet)
  FROM=$(date -u -d "@$(( START_MS / 1000 - 300 ))" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null); TO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  for m in MatchedEvents Invocations FailedInvocations; do
    v=$(aws cloudwatch get-metric-statistics --namespace AWS/Events --metric-name "$m" --dimensions Name=RuleName,Value="$RULE" \
      --start-time "$FROM" --end-time "$TO" --period 3600 --statistics Sum --query "Datapoints[0].Sum" --output text 2>/dev/null)
    echo "        EventBridge $m: ${v:-None}"
  done
  for g in "$FMT_LOGS" "$RESP_LOGS"; do
    echo "        last lines of $g:"
    aws logs filter-log-events --log-group-name "$g" --start-time "$START_MS" --query 'events[-5:].message' --output text 2>/dev/null \
      | tr '\t' '\n' | cut -c1-300 | sed 's/^/          /'
  done
  echo "        MatchedEvents None = the event never reached the rule; errors or 'skipped' above = the function ran. Send this output for help."
fi

# TC-15-L06: the responder only tagged; the rule was NOT removed by the automation (ADR 0001)
STILL=$(aws ec2 describe-security-groups --group-ids "$SG" \
  --query "length(SecurityGroups[0].IpPermissions[?ToPort==\`22\`].IpRanges[] | [?CidrIp=='0.0.0.0/0'])" --output text 2>/dev/null)
[ "${STILL:-0}" = "1" ] && pass "TC-15-L06 the responder tagged the group but left the rule for a person to remove" \
  || fail "TC-15-L06 the test rule disappeared before the script removed it (expected it to still be there)"

# TC-15-L07: the script closes the port again
close_port; trap - EXIT
LEFT=$(aws ec2 describe-security-groups --group-ids "$SG" --query "length(SecurityGroups[0].IpPermissions)" --output text 2>/dev/null)
[ "${LEFT:-1}" = "0" ] && pass "TC-15-L07 test group is closed again (no inbound rules)" || fail "TC-15-L07 test group still has $LEFT inbound rule(s)"

echo
echo "Result: $PASSED passed, $FAILED failed"
echo "Manual check TC-15-M01: an email '[DELIBERATE TEST] HIGH: AuthorizeSecurityGroupIngress ...' arrived (check junk)."
[ "$FAILED" -eq 0 ]
