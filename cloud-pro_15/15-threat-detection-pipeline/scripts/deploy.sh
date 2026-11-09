#!/usr/bin/env bash
# Deploys the infrastructure. Run from anywhere: ./scripts/deploy.sh
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
terraform init -upgrade
terraform fmt -recursive
terraform validate
terraform apply -auto-approve
terraform output
