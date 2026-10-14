#!/usr/bin/env bash
# First deploy only. The ECS service needs an image to start, and the
# ECR repository must exist before an image can be pushed. This breaks that loop.
set -euo pipefail
cd "$(dirname "$0")/.."

# Must match var.aws_region in infrastructure/variables-common.tf
REGION="${TF_VAR_aws_region:-eu-north-1}"
echo "Using region: $REGION"
REPO_NAME="container-app-dev-app"

terraform -chdir=infrastructure init -upgrade
terraform -chdir=infrastructure apply -auto-approve -target=aws_ecr_repository.app

REPO_URL=$(aws ecr describe-repositories --region "$REGION" --repository-names "$REPO_NAME" \
  --query 'repositories[0].repositoryUri' --output text)
REGISTRY="${REPO_URL%%/*}"

# Tags are immutable, so only build and push if the bootstrap image isn't there yet.
if aws ecr describe-images --region "$REGION" --repository-name "$REPO_NAME" \
     --image-ids imageTag=bootstrap >/dev/null 2>&1; then
  echo "Image $REPO_NAME:bootstrap already exists - skipping build and push."
else
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
  # --platform makes Apple Silicon Macs build an image Fargate (x86_64) can run
  docker build --platform linux/amd64 -t "$REPO_URL:bootstrap" .
  docker push "$REPO_URL:bootstrap"
fi

terraform -chdir=infrastructure apply -auto-approve
terraform -chdir=infrastructure output
