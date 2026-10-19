#!/usr/bin/env bash
# Read-only checks to run BEFORE deploying projects 06-12 in my own AWS account.
# It creates nothing and costs nothing. Run from the repo root: ./scripts/preflight.sh
# Each line ends in OK, WARN (read the hint) or FAIL (fix before deploying).
set -uo pipefail

REGION_WANTED="eu-north-1"
FAILS=0
WARNS=0
ok()   { printf '  OK    %s\n' "$1"; }
warn() { printf '  WARN  %s\n        -> %s\n' "$1" "$2"; WARNS=$((WARNS + 1)); }
fail() { printf '  FAIL  %s\n        -> %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }

# Tries a harmless read-only call. A deny from the organisation's SCP shows up here.
can_call() {
  local label="$1"; shift
  local out
  if out=$(aws "$@" --region "$REGION_WANTED" 2>&1 >/dev/null); then
    ok "$label"
  elif echo "$out" | grep -qi "service control policy"; then
    fail "$label" "Blocked by your organisation's SCP. Send me the exact error before deploying the project that needs it."
  elif echo "$out" | grep -qiE "AccessDenied|UnauthorizedOperation|not authorized"; then
    fail "$label" "Access denied: $(echo "$out" | head -1 | cut -c1-160)"
  else
    warn "$label" "Unexpected error: $(echo "$out" | head -1 | cut -c1-160)"
  fi
}

echo "== 1. Tools"
for t in aws terraform git; do
  if have "$t"; then ok "$t installed"; else fail "$t not found" "Install it (see BUILD-GUIDE.md Part B), then reopen the terminal."; fi
done
if have python || have python3; then ok "python installed"; else warn "python not found" "Needed for project 06's tests."; fi
have aws || { echo; echo "Stopping: the AWS CLI is required for the remaining checks."; exit 1; }

echo
echo "== 2. Who and where"
ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || true)
if [ -z "$ARN" ]; then
  fail "Not signed in to AWS" "Run: aws configure   (region eu-north-1)"
  echo; echo "Stopping: fix sign-in first."; exit 1
elif [[ "$ARN" == *":root" ]]; then
  fail "Signed in as the ROOT user" "Delete the root access keys and use your admin IAM user (BUILD-GUIDE.md A5-A6)."
else
  ok "Signed in as ${ARN##*/}"
fi
CFG_REGION=$(aws configure get region 2>/dev/null || true)
if [ "$CFG_REGION" = "$REGION_WANTED" ]; then ok "CLI default region is $REGION_WANTED"
else fail "CLI default region is '${CFG_REGION:-not set}'" "Run: aws configure set region $REGION_WANTED"; fi
for v in AWS_REGION AWS_DEFAULT_REGION; do
  val="${!v:-}"
  if [ -n "$val" ] && [ "$val" != "$REGION_WANTED" ]; then
    fail "$v is set to $val (it overrides your config)" "Run: export $v=$REGION_WANTED   or   unset $v"
  fi
done

echo
echo "== 3. Services each project needs (read-only calls)"
can_call "06  S3"                    s3api list-buckets
can_call "06  Lambda"                lambda list-functions --max-items 1
can_call "06  Step Functions"        stepfunctions list-state-machines --max-results 1
can_call "06  EventBridge"           events list-rules --limit 1
can_call "06  DynamoDB"              dynamodb list-tables --max-items 1
can_call "06  SQS"                   sqs list-queues --max-results 1
can_call "06  SNS"                   sns list-topics
can_call "07  CloudTrail"            cloudtrail describe-trails
can_call "07  AWS Config"            configservice describe-config-rules
can_call "07  CloudWatch Logs"       logs describe-log-groups --limit 1
can_call "08  Transit Gateway"       ec2 describe-transit-gateways
can_call "08  Reachability Analyzer" ec2 describe-network-insights-paths
can_call "09  SSM"                   ssm describe-instance-information --max-items 1
can_call "09  CloudWatch alarms"     cloudwatch describe-alarms --max-records 1
can_call "10  VPC endpoints"         ec2 describe-vpc-endpoints
can_call "11  Route 53 private zones" route53 list-hosted-zones --max-items 1
can_call "11  DNS Firewall"          route53resolver list-firewall-rule-groups --max-results 1
can_call "12  Load balancers"        elbv2 describe-load-balancers --page-size 1
can_call "12  AWS WAF (regional)"    wafv2 list-web-acls --scope REGIONAL --limit 1

echo
echo "== 4. Things that break specific projects"
RECORDERS=$(aws configservice describe-configuration-recorders --region "$REGION_WANTED" \
  --query 'length(ConfigurationRecorders)' --output text 2>/dev/null || echo "?")
if [ "$RECORDERS" = "0" ]; then ok "07  No AWS Config recorder yet (the project can create one)"
elif [ "$RECORDERS" = "?" ]; then warn "07  Couldn't check for a Config recorder" "If deploy fails with MaxNumberOfConfigurationRecordersExceeded, add create_config_recorder = false to terraform.tfvars."
else warn "07  A Config recorder already exists (only one is allowed)" "In cloud-pro_7/.../infrastructure/terraform.tfvars add: create_config_recorder = false"; fi

TRAILS=$(aws cloudtrail describe-trails --region "$REGION_WANTED" --query 'length(trailList)' --output text 2>/dev/null || echo "?")
case "$TRAILS" in
  0) ok "07  No CloudTrail trails yet (yours will be free for management events)" ;;
  "?") warn "07  Couldn't count CloudTrail trails" "Not a blocker." ;;
  *) warn "07  $TRAILS trail(s) already exist" "Your trail will be a second copy of events (about \$2 per 100,000 events). Fine for a few hours; destroy it the same day." ;;
esac

DEFAULT_VPC=$(aws ec2 describe-vpcs --region "$REGION_WANTED" --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
if [ -n "$DEFAULT_VPC" ] && [ "$DEFAULT_VPC" != "None" ]; then ok "07  Default VPC exists (used by the deliberate-violation test)"
else warn "07  No default VPC" "Create one (free) before Part 7: aws ec2 create-default-vpc --region $REGION_WANTED"; fi

VPCS=$(aws ec2 describe-vpcs --region "$REGION_WANTED" --query 'length(Vpcs)' --output text 2>/dev/null || echo "?")
if [ "$VPCS" = "?" ]; then warn "08  Couldn't count VPCs" "Project 08 creates 3 VPCs; the usual limit is 5 per region."
elif [ "$VPCS" -le 2 ]; then ok "08  $VPCS VPC(s) now; room for project 08's 3 more (limit 5)"
else warn "08  $VPCS VPCs already exist; project 08 adds 3 (usual limit is 5)" "Destroy leftover project VPCs first (see section 5)."; fi

EIPS=$(aws ec2 describe-addresses --region "$REGION_WANTED" --query 'length(Addresses)' --output text 2>/dev/null || echo "?")
if [ "$EIPS" = "0" ]; then ok "09  No Elastic IPs in use"
elif [ "$EIPS" = "?" ]; then warn "09  Couldn't count Elastic IPs" "Not a blocker."
else warn "09  $EIPS Elastic IP(s) already allocated" "Each costs about \$0.005/hour. Release any you don't need."; fi

for TYPE in t3.nano t4g.nano t4g.micro; do
  N=$(aws ec2 describe-instance-type-offerings --region "$REGION_WANTED" --location-type region \
    --filters Name=instance-type,Values="$TYPE" --query 'length(InstanceTypeOfferings)' --output text 2>/dev/null || echo "?")
  if [ "$N" = "1" ]; then ok "Instance type $TYPE available in $REGION_WANTED"
  else warn "Instance type $TYPE not confirmed in $REGION_WANTED" "Send me this line before deploying 07, 09 or 10."; fi
done

echo
echo "== 5. Leftovers still running from earlier projects (these cost money)"
LEFT=$(aws resourcegroupstaggingapi get-resources --region "$REGION_WANTED" --tag-filters Key=ManagedBy,Values=terraform \
  --query 'ResourceTagMappingList[].ResourceARN' --output text 2>/dev/null || echo "?")
if [ -z "$LEFT" ]; then ok "Nothing tagged ManagedBy=terraform is running"
elif [ "$LEFT" = "?" ]; then warn "Couldn't run the leftover check" "Check Billing -> Cost Explorer instead."
else
  warn "These project resources still exist:" "Run that project's ./scripts/destroy.sh (deleted items can show for a few minutes)."
  echo "$LEFT" | tr '\t' '\n' | sed 's/^/        /'
fi

echo
echo "Result: $FAILS FAIL, $WARNS WARN"
if [ "$FAILS" -gt 0 ]; then
  echo "Fix the FAIL lines first, or send them to me."
  exit 1
fi
echo "Ready to build."
