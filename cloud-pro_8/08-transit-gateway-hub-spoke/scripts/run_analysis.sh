#!/usr/bin/env bash
# Live test cases TC-08-L01..L03: checks the three paths against the segmentation switch
# and prints PASS/FAIL for each.
#
# Two ways of checking, picked automatically:
#   1. VPC Reachability Analyzer (about $0.10 per path). Used when the account allows it.
#   2. Route check (free). Used when Reachability Analyzer is denied
#      (NetworkInsights.AccessDenied / tiros:CreateQuery). It reads the real route tables,
#      peering connections and probe security groups from AWS and works out whether
#      TCP 443 can get from one VPC to the other and back.
#
#   ./scripts/run_analysis.sh            # try Reachability Analyzer, fall back if denied
#   ./scripts/run_analysis.sh --routes   # go straight to the free route check
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"

PORT="${TEST_PORT:-443}"
MODE=auto
[ "${1:-}" = "--routes" ] && MODE=routes

PASSED=0; FAILED=0
SWITCH=$(terraform output -raw allow_app_to_data)
VPC_JSON=$(terraform output -json vpc_ids)

vpc_id()   { echo "$VPC_JSON" | grep -o "\"$1\": *\"vpc-[0-9a-f]*\"" | grep -o 'vpc-[0-9a-f]*'; }
vpc_cidr() { aws ec2 describe-vpcs --vpc-ids "$1" --query 'Vpcs[0].CidrBlock' --output text; }

# Reachability Analyzer. Prints "<True|False|None> <explanation>", or "DENIED".
ra_check() {
  local path_id=$1 out analysis status found why
  if ! out=$(aws ec2 start-network-insights-analysis --network-insights-path-id "$path_id" \
      --query 'NetworkInsightsAnalysis.NetworkInsightsAnalysisId' --output text 2>&1); then
    if echo "$out" | grep -q -e 'AccessDenied' -e 'UnauthorizedOperation'; then echo "DENIED"
    else echo "$out" >&2; echo "None START_FAILED"; fi
    return
  fi
  analysis=$out
  for _ in $(seq 1 30); do
    status=$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$analysis" \
      --query 'NetworkInsightsAnalyses[0].Status' --output text)
    [ "$status" != "running" ] && break
    sleep 5
  done
  found=$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$analysis" \
    --query 'NetworkInsightsAnalyses[0].NetworkPathFound' --output text)
  why=$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$analysis" \
    --query 'NetworkInsightsAnalyses[0].Explanations[0].ExplanationCode' --output text)
  [ "$found" = "True" ] && why="-"
  echo "$found $why"
}

# Free route check. Prints "<True|False> <explanation>".
route_check() {
  local from=$1 to=$2 fv tv fc tc pcx state back sg allowed
  fv=$(vpc_id "$from"); tv=$(vpc_id "$to")
  fc=$(vpc_cidr "$fv"); tc=$(vpc_cidr "$tv")

  # 1. Does the source VPC have an active route to the destination through a peering?
  pcx=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$fv" \
    --query "RouteTables[].Routes[?DestinationCidrBlock=='$tc' && State=='active'][].VpcPeeringConnectionId | [0]" --output text)
  if [ -z "$pcx" ] || [ "$pcx" = "None" ]; then echo "False NO_ROUTE_TO_DESTINATION"; return; fi

  # 2. Is that peering connection active?
  state=$(aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$pcx" \
    --query 'VpcPeeringConnections[0].Status.Code' --output text)
  if [ "$state" != "active" ]; then echo "False PEERING_NOT_ACTIVE($state)"; return; fi

  # 3. Can the reply get back? (destination VPC routes the source CIDR over the same peering)
  back=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$tv" \
    --query "length(RouteTables[].Routes[?DestinationCidrBlock=='$fc' && VpcPeeringConnectionId=='$pcx' && State=='active'][])" --output text)
  if [ "$back" = "0" ]; then echo "False NO_RETURN_ROUTE"; return; fi

  # 4. Does the destination probe's security group allow the test port from the source VPC?
  sg=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$tv" "Name=group-name,Values=*-probe-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)
  allowed=$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$sg" \
    --query "length(SecurityGroupRules[?IsEgress==\`false\` && CidrIpv4=='$fc' && (IpProtocol=='-1' || (IpProtocol=='tcp' && FromPort<=\`$PORT\` && ToPort>=\`$PORT\`))])" --output text)
  if [ "$allowed" = "0" ]; then echo "False SECURITY_GROUP_BLOCKS_PORT_$PORT"; return; fi

  echo "True -"
}

echo "== Project 08 live test cases (allow_app_to_data = $SWITCH)"
[ "$MODE" = "routes" ] && echo "   Method: route check (free)"
printf '      %-9s %-16s %-10s %-9s %-7s %s\n' "" "PATH" "REACHABLE" "EXPECTED" "METHOD" "EXPLANATION (if blocked)"
ID=0

for name in app_to_shared data_to_shared app_to_data; do
  ID=$((ID + 1))
  from=${name%%_to_*}; to=${name##*_to_}
  EXPECTED=True
  [ "$name" = "app_to_data" ] && [ "$SWITCH" != "true" ] && EXPECTED=False

  RESULT=""
  if [ "$MODE" = "auto" ]; then
    RESULT=$(ra_check "$(terraform output -raw "path_${name}")")
    if [ "$RESULT" = "DENIED" ]; then
      echo "   Reachability Analyzer is not allowed in this account (tiros:CreateQuery denied)."
      echo "   Switching to the free route check for all paths."
      MODE=routes; RESULT=""
    else
      METHOD=RA
    fi
  fi
  if [ -z "$RESULT" ]; then RESULT=$(route_check "$from" "$to"); METHOD=routes; fi

  FOUND=${RESULT%% *}; WHY=${RESULT#* }
  if [ "$FOUND" = "$EXPECTED" ]; then RES=PASS; PASSED=$((PASSED + 1)); else RES=FAIL; FAILED=$((FAILED + 1)); fi
  printf '  %-4s %-9s %-16s %-10s %-9s %-7s %s\n' "$RES" "TC-08-L0$ID" "${name//_/-}" "$FOUND" "$EXPECTED" "$METHOD" "$WHY"
done
echo
echo "Result: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
