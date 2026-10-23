#!/usr/bin/env bash
# Live test cases against the deployed project (costs a fraction of a cent).
# Run after ./scripts/deploy.sh. Prints PASS/FAIL for each test case.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths into C:/Program Files/Git/...
cd "$(dirname "$0")/.."
# Pick a Python that really runs. On Windows, "python3" is often a Microsoft Store shortcut
# that only prints "Python was not found", so each candidate is tested before it is used.
PY=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1 && "$c" -c "import json" >/dev/null 2>&1; then PY="$c"; break; fi
done
if [ -z "$PY" ]; then
  echo "No working Python found. Install it from python.org (tick 'Add python.exe to PATH'), or activate the project's .venv, then run this again."
  exit 1
fi
OUT=.lambda-out.json
PASSED=0; FAILED=0
pass() { echo "  PASS  $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }

SECRET=$(terraform -chdir=infrastructure output -raw secret_arn)
CLIENT=$(terraform -chdir=infrastructure output -raw client_function)
API=$(terraform -chdir=infrastructure output -raw api_function)

invoke() {   # invoke <function> <json payload> -> prints statusCode
  aws lambda invoke --function-name "$1" --cli-binary-format raw-in-base64-out \
    --payload "$2" "$OUT" >/dev/null 2>&1 || { echo "ERR"; return; }
  "$PY" -c "import json;print(json.load(open('$OUT'))['statusCode'])"
}
current_key() { aws secretsmanager get-secret-value --secret-id "$SECRET" --version-stage AWSCURRENT --query SecretString --output text; }
rotate_and_wait() {
  local v
  v=$(aws secretsmanager rotate-secret --secret-id "$SECRET" --query VersionId --output text) || return 1
  for _ in $(seq 1 30); do
    [ "$(aws secretsmanager get-secret-value --secret-id "$SECRET" --version-stage AWSCURRENT --query VersionId --output text)" = "$v" ] && return 0
    sleep 2
  done
  return 1
}

echo "== Project 13 live test cases"

# TC-13-L01: the client app works with the first key
[ "$(invoke "$CLIENT" '{}')" = "200" ] && pass "TC-13-L01 client calls the API with the current key" || fail "TC-13-L01 client call"

KEY1=$(current_key)

# TC-13-L02: a rotation completes all four steps
if rotate_and_wait; then pass "TC-13-L02 rotation 1 completed (create, set, test, finish)"; else fail "TC-13-L02 rotation 1 did not finish (see the rotation function's logs)"; fi
KEY2=$(current_key)
[ "$KEY1" != "$KEY2" ] && pass "TC-13-L03 the key value changed" || fail "TC-13-L03 the key did not change"

# TC-13-L04: the previous key still works (cached clients don't break)
[ "$(invoke "$API" "{\"api_key\":\"$KEY1\"}")" = "200" ] && pass "TC-13-L04 previous key still accepted" || fail "TC-13-L04 previous key rejected too early"

# TC-13-L05: the client keeps working straight after a rotation
[ "$(invoke "$CLIENT" '{}')" = "200" ] && pass "TC-13-L05 client still works after rotation" || fail "TC-13-L05 client broke after rotation"

# TC-13-L06: after a second rotation, the key from two rotations ago is revoked
if rotate_and_wait; then
  [ "$(invoke "$API" "{\"api_key\":\"$KEY1\"}")" = "403" ] && pass "TC-13-L06 key from two rotations ago is revoked" || fail "TC-13-L06 old key still accepted"
  [ "$(invoke "$API" "{\"api_key\":\"$KEY2\"}")" = "200" ] && pass "TC-13-L07 previous key (rotation 1) still accepted" || fail "TC-13-L07 previous key rejected"
else
  fail "TC-13-L06 rotation 2 did not finish"
fi

# TC-13-L08: a made-up key is refused
[ "$(invoke "$API" '{"api_key":"made-up-key-for-testing"}')" = "403" ] && pass "TC-13-L08 unknown key refused" || fail "TC-13-L08 unknown key accepted"

# TC-13-L09: the registry holds hashes, never a usable key
ITEMS=$(aws dynamodb scan --table-name "$(terraform -chdir=infrastructure output -raw registry_table)" --output json)
if echo "$ITEMS" | grep -q "$(current_key)"; then fail "TC-13-L09 plaintext key found in the registry"; else pass "TC-13-L09 registry contains hashes only"; fi

rm -f "$OUT"
echo
echo "Result: $PASSED passed, $FAILED failed"
echo "CloudTrail RotateSecret events appear within about 15 minutes: CloudTrail -> Event history -> Event name = RotateSecret"
[ "$FAILED" -eq 0 ]
