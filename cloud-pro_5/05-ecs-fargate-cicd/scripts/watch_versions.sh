#!/usr/bin/env bash
# Polls the app every 3 seconds so you can watch a rolling deploy switch versions.
set -uo pipefail
cd "$(dirname "$0")/../infrastructure"
URL=$(terraform output -raw app_url)
while true; do
  printf '%s  ' "$(date +%H:%M:%S)"
  curl -s --max-time 3 "$URL/" || printf 'no response'
  echo
  sleep 3
done
