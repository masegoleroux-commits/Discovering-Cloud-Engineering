#!/usr/bin/env bash
# Live test case TC-12-L05 (DELIBERATE TEST): floods the site from your computer so
# AWS WAF's rate-based rule (default: 100 requests per IP per minute) starts answering 403.
#   1. Burst: 400 requests, 20 at a time in parallel, so the rate is well over the limit
#      even from far away (sending one at a time from South Africa only reaches ~100/min).
#   2. Watch: small checks every 10 seconds for up to 2 minutes, because WAF needs
#      roughly 30-60 seconds to notice a rate and start blocking.
#   3. If nothing was blocked: asks WAF which client IPs it actually saw. Many different
#      IPs means your network (for example mobile data) spreads requests over several
#      addresses, so no single address reaches the limit.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
SITE=$(terraform output -raw site_url)
ACL_NAME=$(terraform output -raw web_acl_name)
SCOPE=$(terraform output -raw waf_scope)
URL="$SITE/health"
WORK=../.test-work; mkdir -p "$WORK"

# send <count> <parallel>: prints one HTTP status code per request
send() {
  seq 1 "$1" | xargs -P "$2" -I{} curl -s -o /dev/null -m 10 -w "%{http_code}\n" "$URL?n={}" 2>/dev/null
}
count() { grep -c "^$1\$" "$2" 2>/dev/null || true; }

echo "== Project 12 live test case: rate limit (deliberate test) on $URL"
START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
T0=$(date +%s)
send 400 20 > "$WORK/burst.txt"
SECS=$(( $(date +%s) - T0 )); [ "$SECS" -lt 1 ] && SECS=1
OK=$(count 200 "$WORK/burst.txt"); BLOCKED=$(count 403 "$WORK/burst.txt")
echo "        burst: 400 requests in ${SECS}s (about $(( 400 * 60 / SECS )) per minute): $OK allowed, $BLOCKED blocked by WAF"
TOTAL_BLOCKED=$BLOCKED

echo "        watching for blocking (WAF takes about 30-60 seconds to react)..."
for round in $(seq 1 12); do
  send 30 10 > "$WORK/round.txt"
  b=$(count 403 "$WORK/round.txt"); o=$(count 200 "$WORK/round.txt")
  TOTAL_BLOCKED=$((TOTAL_BLOCKED + b))
  echo "        check $round: $o allowed, $b blocked"
  [ "$b" -gt 0 ] && break
  sleep 10
done
echo "Blocking lifts automatically a minute or two after the requests stop."

if [ "$TOTAL_BLOCKED" -gt 0 ]; then
  rm -rf "$WORK"
  echo "  PASS  TC-12-L05 WAF rate limit blocked $TOTAL_BLOCKED requests"; exit 0
fi

# Diagnosis: which client IPs did WAF see?
REGION=eu-north-1; [ "$SCOPE" = "CLOUDFRONT" ] && REGION=us-east-1
ACL_ARN=$(aws wafv2 list-web-acls --scope "$SCOPE" --region "$REGION" \
  --query "WebACLs[?Name=='$ACL_NAME'].ARN | [0]" --output text 2>/dev/null)
END_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "        WAF's view: client IPs in a sample of your requests (WAF samples up to 100):"
aws wafv2 get-sampled-requests --web-acl-arn "$ACL_ARN" --rule-metric-name "$ACL_NAME" \
  --scope "$SCOPE" --region "$REGION" --time-window StartTime="$START_TS",EndTime="$END_TS" --max-items 100 \
  --query "SampledRequests[].Request.ClientIP" --output text 2>/dev/null | tr '\t' '\n' | sort | uniq -c | sort -rn | head -10 | sed 's/^/          /'
echo "        One IP with many requests = WAF saw you as one visitor (re-run in 2 minutes)."
echo "        Many different IPs = your network spreads requests over several addresses; try a home Wi-Fi network."
rm -rf "$WORK"
echo "  FAIL  TC-12-L05 nothing was blocked"
exit 1
