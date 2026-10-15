#!/usr/bin/env bash
# Uploads one good and one bad SYNTHETIC file. Uses 3 Lambda invocations.
set -euo pipefail
cd "$(dirname "$0")/.."
BUCKET=$(terraform -chdir=infrastructure output -raw upload_bucket)

aws s3 cp tests/data/valid_orders.csv   "s3://$BUCKET/incoming/valid_orders.csv"
aws s3 cp tests/data/invalid_orders.csv "s3://$BUCKET/incoming/invalid_orders.csv"
echo "Uploaded. Wait about 30 seconds, then run ./scripts/check_results.sh"
