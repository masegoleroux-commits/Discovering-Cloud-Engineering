#!/usr/bin/env bash
# Calls each route once against the deployed API (about 5 Lambda invocations).
set -euo pipefail
PY=$(command -v python3 || command -v python)   # Windows Git Bash often has only "python"
cd "$(dirname "$0")/../infrastructure"
API=$(terraform output -raw api_base_url)

echo "== Create"
CREATED=$(curl -s -X POST "$API/notes" -H 'Content-Type: application/json' \
  -d '{"title":"First note","content":"Created by the smoke test"}')
echo "$CREATED"
NOTE_ID=$(echo "$CREATED" | "$PY" -c 'import json,sys; print(json.load(sys.stdin)["note_id"])')

echo "== List";        curl -s "$API/notes"; echo
echo "== Get one";     curl -s "$API/notes/$NOTE_ID"; echo
echo "== Bad request"; curl -s -X POST "$API/notes" -H 'Content-Type: application/json' -d '{}' -w ' -> HTTP %{http_code}\n'
echo "== Delete";      curl -s -X DELETE "$API/notes/$NOTE_ID" -o /dev/null -w 'HTTP %{http_code}\n'
