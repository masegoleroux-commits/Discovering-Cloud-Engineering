#!/usr/bin/env bash
# Live test cases TC-12-L06..L07 (DELIBERATE TEST): terminates one web server and checks
# the site stays up while the Auto Scaling group replaces it. Prints PASS/FAIL.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
SITE=$(terraform output -raw site_url)
ASG=$(terraform output -raw asg_name)
DESIRED=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].DesiredCapacity' --output text)
VICTIM=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' --output text)

echo "== Project 12 live test cases: self-healing (deliberate test)"
echo "Terminating $VICTIM (the ASG keeps $DESIRED servers, so it will launch a replacement)..."
aws autoscaling terminate-instance-in-auto-scaling-group --instance-id "$VICTIM" \
  --no-should-decrement-desired-capacity >/dev/null

ERRORS=0; HEALED=0
for i in $(seq 1 36); do
  code=$(curl -s -o /dev/null -m 5 -w "%{http_code}" "$SITE/health")
  [ "$code" = "200" ] || ERRORS=$((ERRORS + 1))
  STATES=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].Instances[].[InstanceId,LifecycleState]' --output text)
  INSERVICE=$(echo "$STATES" | grep InService | grep -vc "$VICTIM")
  echo "        $(date +%H:%M:%S)  site: $code   in service (not counting the victim): $INSERVICE/$DESIRED"
  if [ "$INSERVICE" -ge "$DESIRED" ]; then HEALED=1; break; fi
  sleep 10
done

[ "$ERRORS" -eq 0 ] && echo "  PASS  TC-12-L06 zero failed requests while a server was replaced" \
  || echo "  FAIL  TC-12-L06 $ERRORS failed requests during the replacement"
[ "$HEALED" -eq 1 ] && echo "  PASS  TC-12-L07 the Auto Scaling group replaced the server" \
  || echo "  FAIL  TC-12-L07 no replacement in service after 6 minutes (check the ASG Activity tab)"
[ "$ERRORS" -eq 0 ] && [ "$HEALED" -eq 1 ]
