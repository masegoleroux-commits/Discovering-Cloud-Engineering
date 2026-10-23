#!/usr/bin/env bash
# Live test case TC-10-L07 (DELIBERATE TEST): tries to read the confidential file from YOUR
# computer (outside the VPC). The bucket policy should refuse, even though you are an
# administrator. AccessDenied is the PASSING result.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash on Windows: stop it rewriting /paths (e.g. /dev/sdf) into C:/Program Files/Git/...
cd "$(dirname "$0")/../infrastructure"
DATA=$(terraform output -raw data_bucket)
echo "Reading s3://$DATA/confidential/report.txt from outside the VPC..."
ERR=$(aws s3api get-object --bucket "$DATA" --key confidential/report.txt report-copy.txt 2>&1 >/dev/null)
CODE=$?
rm -f report-copy.txt
if [ $CODE -ne 0 ] && echo "$ERR" | grep -q AccessDenied; then
  echo "  PASS  TC-10-L07 AccessDenied from outside the VPC, even for an administrator"
  exit 0
elif [ $CODE -eq 0 ]; then
  echo "  FAIL  TC-10-L07 the file was readable from outside the VPC"
else
  echo "  FAIL  TC-10-L07 unexpected error: $(echo "$ERR" | tail -1)  (run ./scripts/run_tests.sh first so the file exists)"
fi
exit 1
