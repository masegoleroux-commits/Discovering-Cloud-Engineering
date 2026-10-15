#!/usr/bin/env bash
# DELIBERATE TEST: creates resources that SHOULD be flagged, to prove the baseline works.
# Creates 1 security group, 1 t3.micro instance and 1 unencrypted 1 GB volume.
# Safe to re-run: anything left from an earlier attempt is found and reused, not duplicated.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/.."
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo eu-north-1)}"
PURPOSE="security-baseline-deliberate-test"
SG_NAME="security-baseline-test-open-ssh"
ROLE_NAME="security-baseline-test-no-permissions"
TAG='ResourceType=%s,Tags=[{Key=Purpose,Value=security-baseline-deliberate-test}]'
none() { [ -z "$1" ] || [ "$1" = "None" ]; }

VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
if none "$VPC_ID"; then
  echo "No default VPC in $REGION. Create one first (free): aws ec2 create-default-vpc --region $REGION" >&2
  exit 1
fi
SUBNET_ID=$(aws ec2 describe-subnets --region "$REGION" --filters Name=vpc-id,Values="$VPC_ID" Name=default-for-az,Values=true --query 'Subnets[0].SubnetId' --output text)

# Amazon Linux 2023 (x86_64, for t3.micro). AWS publishes this parameter in every region;
# Canonical's Ubuntu parameter returned ParameterNotFound in eu-north-1.
AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text 2>/dev/null || true)
if none "$AMI_ID"; then
  # Fallback: newest Amazon-owned AL2023 image, found with EC2 instead of SSM
  AMI_ID=$(aws ec2 describe-images --region "$REGION" --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-kernel-*-x86_64" "Name=state,Values=available" \
    --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)
fi
if none "$AMI_ID"; then
  echo "Couldn't find an Amazon Linux 2023 image in $REGION. Nothing was created." >&2
  exit 1
fi
echo "Using image $AMI_ID in $REGION"

# 1. Security group open to SSH from anywhere -> restricted-ssh NON_COMPLIANT + SG-change alarm
SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
  --filters Name=group-name,Values="$SG_NAME" Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' --output text)
if none "$SG_ID"; then
  SG_ID=$(aws ec2 create-security-group --region "$REGION" --group-name "$SG_NAME" \
    --description "DELIBERATE TEST: open SSH" --vpc-id "$VPC_ID" \
    --tag-specifications "$(printf "$TAG" security-group)" --query GroupId --output text)
  echo "Created security group $SG_ID"
else
  echo "Reusing security group $SG_ID from an earlier run"
fi
if ! OUT=$(aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
      --protocol tcp --port 22 --cidr 0.0.0.0/0 2>&1 >/dev/null); then
  if echo "$OUT" | grep -q "InvalidPermission.Duplicate"; then
    echo "  SSH rule already there"
  else
    echo "$OUT" >&2; exit 1
  fi
fi

# 2. Instance that still allows IMDSv1 -> ec2-imdsv2-check NON_COMPLIANT
INSTANCE_ID=$(aws ec2 describe-instances --region "$REGION" \
  --filters Name=tag:Purpose,Values="$PURPOSE" Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
if none "$INSTANCE_ID"; then
  INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" --image-id "$AMI_ID" --instance-type t3.micro \
    --subnet-id "$SUBNET_ID" --security-group-ids "$SG_ID" \
    --credit-specification CpuCredits=standard \
    --metadata-options HttpTokens=optional,HttpEndpoint=enabled \
    --tag-specifications "$(printf "$TAG" instance)" \
    --query 'Instances[0].InstanceId' --output text)
  echo "Started instance $INSTANCE_ID"
else
  echo "Reusing instance $INSTANCE_ID from an earlier run"
  aws ec2 start-instances --region "$REGION" --instance-ids "$INSTANCE_ID" >/dev/null 2>&1 || true
fi
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"
AZ=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)

# 3. Unencrypted volume attached to it -> encrypted-volumes NON_COMPLIANT
#    (if "EBS encryption by default" is on, the volume is encrypted anyway; that's a finding too)
VOL_ID=$(aws ec2 describe-volumes --region "$REGION" \
  --filters Name=tag:Purpose,Values="$PURPOSE" Name=status,Values=creating,available,in-use \
  --query 'Volumes[0].VolumeId' --output text)
if none "$VOL_ID"; then
  VOL_ID=$(aws ec2 create-volume --region "$REGION" --availability-zone "$AZ" --size 1 --volume-type gp3 \
    --no-encrypted --tag-specifications "$(printf "$TAG" volume)" --query VolumeId --output text)
  echo "Created volume $VOL_ID"
  aws ec2 wait volume-available --region "$REGION" --volume-ids "$VOL_ID"
else
  echo "Reusing volume $VOL_ID from an earlier run"
fi
ATTACHED_TO=$(aws ec2 describe-volumes --region "$REGION" --volume-ids "$VOL_ID" \
  --query 'Volumes[0].Attachments[0].InstanceId' --output text)
if [ "$ATTACHED_TO" != "$INSTANCE_ID" ]; then
  VOL_AZ=$(aws ec2 describe-volumes --region "$REGION" --volume-ids "$VOL_ID" --query 'Volumes[0].AvailabilityZone' --output text)
  if [ "$VOL_AZ" = "$AZ" ] && none "$ATTACHED_TO"; then
    aws ec2 attach-volume --region "$REGION" --volume-id "$VOL_ID" --instance-id "$INSTANCE_ID" --device /dev/sdf >/dev/null
  else
    echo "  Volume is in $VOL_AZ or attached elsewhere; Config still checks it, so leaving it as it is."
  fi
fi

# 4. A call that gets AccessDenied -> unauthorized-api-calls alarm.
#    Your admin user can do everything, so assume a temporary role with NO permissions.
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE_NAME" \
    --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::$ACCOUNT_ID:root\"},\"Action\":\"sts:AssumeRole\"}]}" \
    --tags Key=Purpose,Value="$PURPOSE" >/dev/null
  sleep 15   # IAM changes take a few seconds to spread
fi
CREDS=$(aws sts assume-role --role-arn "arn:aws:iam::$ACCOUNT_ID:role/$ROLE_NAME" \
  --role-session-name deliberate-denied-call --query Credentials --output json)
AWS_ACCESS_KEY_ID=$(echo "$CREDS" | grep -o '"AccessKeyId": *"[^"]*"' | cut -d'"' -f4) \
AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | grep -o '"SecretAccessKey": *"[^"]*"' | cut -d'"' -f4) \
AWS_SESSION_TOKEN=$(echo "$CREDS" | grep -o '"SessionToken": *"[^"]*"' | cut -d'"' -f4) \
  aws ec2 describe-instances --region "$REGION" >/dev/null 2>&1 || echo "Denied API call made (expected)."

cat > .test-violations.env <<ENV
SG_ID=$SG_ID
INSTANCE_ID=$INSTANCE_ID
VOL_ID=$VOL_ID
REGION=$REGION
ENV
echo "Ready: SG $SG_ID, instance $INSTANCE_ID, volume $VOL_ID."
echo "Wait about 10-15 minutes, then run ./scripts/compliance_report.sh"
echo "Clean up afterwards with ./scripts/cleanup_test_violations.sh"
