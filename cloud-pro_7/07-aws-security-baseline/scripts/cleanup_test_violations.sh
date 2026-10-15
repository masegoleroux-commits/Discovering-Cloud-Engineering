#!/usr/bin/env bash
# Removes everything create_test_violations.sh made, including leftovers from
# earlier or half-finished runs. It finds them by tag and name, so it doesn't
# need .test-violations.env, and it's safe to run more than once.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/.."
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo eu-north-1)}"
PURPOSE="security-baseline-deliberate-test"
SG_NAME="security-baseline-test-open-ssh"
ROLE_NAME="security-baseline-test-no-permissions"

# 1. Instances (the SG can't be deleted while an instance uses it)
INSTANCES=$(aws ec2 describe-instances --region "$REGION" \
  --filters Name=tag:Purpose,Values="$PURPOSE" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
  echo "Terminating instance(s): $INSTANCES"
  # shellcheck disable=SC2086
  aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCES >/dev/null
  # shellcheck disable=SC2086
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $INSTANCES
fi

# 2. Volumes (they detach when the instance ends, but aren't deleted with it)
for VOL in $(aws ec2 describe-volumes --region "$REGION" \
    --filters Name=tag:Purpose,Values="$PURPOSE" --query 'Volumes[].VolumeId' --output text); do
  [ "$VOL" = "None" ] && continue
  aws ec2 wait volume-available --region "$REGION" --volume-ids "$VOL" 2>/dev/null || true
  aws ec2 delete-volume --region "$REGION" --volume-id "$VOL" && echo "Deleted volume $VOL"
done

# 3. Security groups with the test name, in any VPC
for SG in $(aws ec2 describe-security-groups --region "$REGION" \
    --filters Name=group-name,Values="$SG_NAME" --query 'SecurityGroups[].GroupId' --output text); do
  [ "$SG" = "None" ] && continue
  aws ec2 delete-security-group --region "$REGION" --group-id "$SG" && echo "Deleted security group $SG"
done

# 4. The no-permissions role
if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam delete-role --role-name "$ROLE_NAME" && echo "Deleted role $ROLE_NAME"
fi

rm -f .test-violations.env

# 5. Check
LEFT=$(aws ec2 describe-security-groups --region "$REGION" --filters Name=group-name,Values="$SG_NAME" \
  --query 'length(SecurityGroups)' --output text 2>/dev/null || echo "?")
if [ "$LEFT" = "0" ]; then
  echo "Test resources removed."
else
  echo "Something is still there (security groups left: $LEFT). Wait a minute and run this script again." >&2
  exit 1
fi
