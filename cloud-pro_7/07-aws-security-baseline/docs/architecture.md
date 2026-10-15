# Architecture

```mermaid
flowchart LR
  API[Every API call] --> CT[CloudTrail]
  CT --> S3T[(S3 trail bucket<br/>log file validation)]
  CT --> LG[CloudWatch Logs]
  LG --> MF[4 metric filters] --> AL[4 alarms] --> SNS[SNS email]
  RES[S3, security groups,<br/>volumes, instances] --> CR[Config recorder]
  CR --> RULES[6 managed rules]
  CR --> S3C[(S3 config bucket)]
```

**CloudTrail** answers *who did what, and when*. **AWS Config** answers *what does this resource look like now, and is that allowed*. They complement each other: CloudTrail sees someone open port 22; Config tells me the security group now breaks the `restricted-ssh` rule.

| Component | AWS name |
|-----------|----------|
| Trail | `security-baseline-dev-trail` |
| Trail bucket | `security-baseline-dev-trail-<account_id>` |
| Trail log group | `/security-baseline-dev/cloudtrail` |
| Config recorder / delivery channel | `security-baseline-dev-recorder` / `security-baseline-dev-delivery` |
| Config bucket | `security-baseline-dev-config-<account_id>` |
| Alarms | `security-baseline-dev-<event>-alarm` (4) |
| SNS topic | `security-baseline-dev-security-alerts` |
