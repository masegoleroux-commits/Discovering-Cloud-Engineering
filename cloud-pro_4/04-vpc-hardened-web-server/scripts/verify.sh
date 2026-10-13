#!/usr/bin/env bash
# Checks the website responds, hides its version, and that SSH is closed.
set -uo pipefail
cd "$(dirname "$0")/../infrastructure"
URL=$(terraform output -raw web_url)
IP=$(terraform output -raw public_ip)

echo "== HTTP headers from $URL"
curl -sI "$URL" | grep -Ei '^(HTTP|Server)'

echo "== Port 22 (should time out or be refused)"
if timeout 5 bash -c "</dev/tcp/$IP/22" 2>/dev/null; then
  echo "Port 22 is OPEN"
else
  echo "Port 22 is closed - no SSH access"
fi
