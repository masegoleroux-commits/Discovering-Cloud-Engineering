#!/usr/bin/env bash
# Live test cases TC-09-L06..L09 (DELIBERATE TEST): knocks on closed ports of the NAT
# instance from your computer. The security group drops them, and VPC Flow Logs record
# each attempt as REJECT. Prints PASS/FAIL for each.
#
# Some networks (mobile data, offices, antivirus "web shields") run a proxy that answers
# on ports such as 8080 itself, so a knock can look "open" even though it never reached AWS.
# That's why the final verdict for a port comes from VPC Flow Logs (what AWS actually saw):
# REJECT = blocked by AWS (pass); ACCEPT = really open (fail).
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
NAT_IP=$(terraform output -raw nat_public_ip)
NAT_ID=$(terraform output -raw nat_instance_id)
LOGS=$(terraform output -raw flow_log_group)
NAT_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids "$NAT_ID" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
START=$(( ($(date +%s) - 900) * 1000 ))

# flow_count <port> <ACCEPT|REJECT>: Flow Log records for traffic to the NAT on that port
flow_count() {
  local n
  n=$(aws logs filter-log-events --log-group-name "$LOGS" --start-time "$START" \
    --filter-pattern "[version, account, eni, src, dst=\"$NAT_PRIVATE_IP\", srcport, dstport=$1, protocol, packets, bytes, start, end, action=\"$2\", status]" \
    --query 'length(events)' --output text 2>/dev/null)
  case "$n" in ''|None) echo 0 ;; *) echo "$n" ;; esac
}

echo "== Project 09 live test cases: blocked traffic (deliberate test)"
ANSWERED=""
N=5
for port in 22 3389 8080; do
  N=$((N + 1))
  if timeout 3 bash -c "</dev/tcp/$NAT_IP/$port" 2>/dev/null; then
    echo "  ....  TC-09-L0$N port $port: something answered. Checking Flow Logs to see whether it was AWS or a proxy on your network"
    ANSWERED="$ANSWERED $N:$port"
  else
    pass "TC-09-L0$N port $port on the NAT is blocked"
  fi
done

# Flow Logs arrive in about 1-10 minutes. Wait for the port-22 REJECT (TC-09-L09); by then
# the other knocks have usually arrived too.
echo "  ... waiting for Flow Logs (checks every 30 seconds, up to 10 minutes)"
FOUND=0
for _ in $(seq 1 20); do
  [ "$(flow_count 22 REJECT)" -gt 0 ] 2>/dev/null && { FOUND=1; break; }
  sleep 30
done
[ "$FOUND" = 1 ] && pass "TC-09-L09 Flow Logs recorded a blocked port-22 attempt as REJECT" \
  || fail "TC-09-L09 no REJECT records yet; Flow Logs can lag, run the 'rejected-traffic' saved query in a few minutes"

# Verdict for any port that "answered"
for item in $ANSWERED; do
  N=${item%%:*}; port=${item#*:}
  A=$(flow_count "$port" ACCEPT); R=$(flow_count "$port" REJECT)
  if [ "$A" -gt 0 ] 2>/dev/null; then
    fail "TC-09-L0$N port $port on the NAT is OPEN: AWS accepted $A connection(s). Check the NAT security group"
  elif [ "$R" -gt 0 ] 2>/dev/null; then
    pass "TC-09-L0$N port $port blocked by AWS ($R REJECT in Flow Logs). The answer came from a proxy on your own network"
  else
    fail "TC-09-L0$N port $port: no Flow Log records yet, so AWS's verdict is unknown. Run this script again in 5 minutes"
  fi
done

echo
echo "Result: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
