#!/usr/bin/env bash
# Deploys the infrastructure. Run from anywhere: ./scripts/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/../infrastructure"
terraform init -upgrade
terraform fmt -recursive
terraform validate
terraform apply -auto-approve
terraform output
