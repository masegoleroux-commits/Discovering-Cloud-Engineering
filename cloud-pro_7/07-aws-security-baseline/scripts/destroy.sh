#!/usr/bin/env bash
# Deletes everything this project created, including the CloudTrail and Config buckets.
set -euo pipefail
cd "$(dirname "$0")/../infrastructure"
terraform destroy -auto-approve
