# 0004 Detect and alert, no automatic fixes yet

Status: Accepted

## Context
Config can automatically fix non-compliant resources using SSM Automation.

## Decision
Detect and alert only.

## Alternatives rejected
- **Automatic remediation:** can break running systems if a rule is wrong.

## Consequences
A person reviews every finding. Once the rules are trusted, the safest fixes (such as removing `0.0.0.0/0` on port 22) are good candidates for automation.
