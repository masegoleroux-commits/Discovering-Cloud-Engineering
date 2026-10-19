#!/usr/bin/env bash
# Prints each Config rule's status and the resources that fail it.
set -euo pipefail
aws configservice describe-compliance-by-config-rule \
  --query 'ComplianceByConfigRules[].[ConfigRuleName,Compliance.ComplianceType]' --output table

for RULE in restricted-ssh encrypted-volumes ec2-imdsv2-check s3-bucket-public-read-prohibited s3-bucket-server-side-encryption-enabled; do
  echo "== $RULE: non-compliant resources"
  aws configservice get-compliance-details-by-config-rule --config-rule-name "$RULE" \
    --compliance-types NON_COMPLIANT \
    --query 'EvaluationResults[].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId' --output text
done
