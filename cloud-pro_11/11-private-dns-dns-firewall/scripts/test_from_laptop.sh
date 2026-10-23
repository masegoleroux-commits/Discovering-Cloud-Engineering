#!/usr/bin/env bash
# Live test case TC-11-L07: the private zone must NOT resolve from outside the VPC.
# A failed lookup is the PASSING result.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
ZONE=$(terraform output -raw private_zone)
echo "Looking up app.${ZONE} from this computer (outside the VPC):"
OUT=$(nslookup "app.${ZONE}" 2>&1)
echo "$OUT" | tail -3
# Any 10.x answer means the private zone leaked; anything else (NXDOMAIN, can't find) is a pass.
if echo "$OUT" | grep -Eq 'Address(es)?:[[:space:]]*10\.'; then
  echo "  FAIL  TC-11-L07 app.${ZONE} resolved from outside the VPC"; exit 1
fi
echo "  PASS  TC-11-L07 app.${ZONE} does not resolve outside the VPC"
