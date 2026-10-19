#!/usr/bin/env bash
# Deletes everything this project created.
set -euo pipefail
cd "$(dirname "$0")/../infrastructure"
terraform destroy -auto-approve
