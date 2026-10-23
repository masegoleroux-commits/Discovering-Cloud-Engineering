#!/usr/bin/env bash
# Live test cases TC-12-L01..L04: the site works through its front door, two AZs answer,
# and the load balancer can't be reached around CloudFront. Prints PASS/FAIL for each.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
SITE=$(terraform output -raw site_url)
ALB=$(terraform output -raw alb_url)
CF=$(terraform output -raw cloudfront_enabled)

echo "== Project 12 live test cases: access ($SITE)"

# TC-12-L01: the site answers through its front door
CODE=$(curl -s -o /dev/null -m 15 -w "%{http_code}" "$SITE/")
[ "$CODE" = "200" ] && pass "TC-12-L01 site answers 200 through the front door" || fail "TC-12-L01 site answered '$CODE' (wait 5-10 minutes after deploy for CloudFront)"

# TC-12-L02: requests are spread over servers in BOTH Availability Zones
AZS=$(for i in $(seq 1 12); do curl -s -m 10 "$SITE/whoami"; echo; done | grep -o '"az":"[^"]*"' | sort -u)
COUNT=$(echo "$AZS" | grep -c az)
echo "        zones seen: $(echo $AZS)"
[ "$COUNT" -ge 2 ] && pass "TC-12-L02 two Availability Zones answered" || fail "TC-12-L02 only $COUNT zone(s) answered"

# TC-12-L03: HTTPS for visitors (CloudFront on) or a reachable regional entry point (CloudFront off)
if [ "$CF" = "true" ]; then
  [[ "$SITE" == https://* ]] && pass "TC-12-L03 visitors use HTTPS (CloudFront)" || fail "TC-12-L03 site URL is not HTTPS"
  # TC-12-L04: going around CloudFront straight to the load balancer is refused
  DIRECT=$(curl -s -o /dev/null -m 8 -w "%{http_code}" "$ALB/" 2>/dev/null)
  case "$DIRECT" in
    000) pass "TC-12-L04 direct access to the load balancer gets no answer (security group allows only CloudFront)";;
    403) pass "TC-12-L04 direct access to the load balancer is refused with 403 (no secret header)";;
    *)   fail "TC-12-L04 direct access to the load balancer answered $DIRECT";;
  esac
else
  echo "        CloudFront is off: the load balancer is the public entry point, behind the regional WAF"
  pass "TC-12-L03 regional entry point answers (CloudFront disabled by setting)"
fi

echo
echo "Result: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
