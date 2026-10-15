#!/usr/bin/env bash
# Shows the latest executions, the rows in DynamoDB and the dead-letter queue message.
set -euo pipefail
PY=$(command -v python3 || command -v python)   # Windows Git Bash often has only "python"
cd "$(dirname "$0")/../infrastructure"
SFN=$(terraform output -raw state_machine_arn)
TABLE=$(terraform output -raw orders_table)
DLQ=$(terraform output -raw dead_letter_queue_url)

echo "== Latest executions"
aws stepfunctions list-executions --state-machine-arn "$SFN" --max-results 5 \
  --query 'executions[].[name,status]' --output table

echo "== Rows in $TABLE"
aws dynamodb scan --table-name "$TABLE" \
  --query 'Items[].[order_id.S,amount.N,currency.S]' --output table

echo "== Dead-letter queue (message stays in the queue)"
aws sqs receive-message --queue-url "$DLQ" --max-number-of-messages 1 --visibility-timeout 0 \
  --query 'Messages[0].Body' --output text | "$PY" -m json.tool || echo "(empty)"
