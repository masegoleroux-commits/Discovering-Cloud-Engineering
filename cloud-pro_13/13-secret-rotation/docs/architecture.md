# Architecture – 13 Automatic Secret Rotation

```mermaid
flowchart LR
  SCH["Rotation schedule<br/>every 7 days"] --> SM["Secrets Manager<br/>secret: partner-api-key"]
  SM -->|"invokes"| ROT["Rotation Lambda<br/>create → set → test → finish"]
  ROT -->|"1. createSecret: new key as AWSPENDING"| SM
  ROT -->|"2. setSecret: register new key"| REG[("Key registry<br/>DynamoDB")]
  ROT -->|"3. testSecret: call API with new key"| API["Demo API<br/>Lambda"]
  ROT -->|"4. finishSecret: AWSPENDING → AWSCURRENT<br/>key from two rotations ago revoked"| SM
  APP["Client app<br/>Lambda"] -->|"GetSecretValue (cached)"| SM
  APP -->|"request + current key"| API
  API -->|"is this key valid?"| REG
  SM -. "RotateSecret, GetSecretValue" .-> CT["CloudTrail<br/>proof of every rotation"]
```

| Piece | What it does |
|-------|--------------|
| Secret `partner-api-key` | The API key, with a rotation schedule every 7 days (and an on-demand "rotate now") |
| Rotation Lambda | Runs the four steps; only Secrets Manager can invoke it |
| Key registry (DynamoDB) | Stands in for a partner system that has to accept the new key; holds the current and previous keys |
| Demo API Lambda | Accepts a request only if its key is in the registry |
| Client app Lambda | Reads the secret (cached) and calls the API |
| CloudTrail | Records every rotation and every read of the secret |

## AWS names

| Component | Name |
|-----------|------|
| Secret | `secret-rotation-dev/partner-api-key` |
| Lambdas | `secret-rotation-dev-rotation`, `-api`, `-client` |
| Key registry table | `secret-rotation-dev-key-registry` |
| Log groups | `/aws/lambda/secret-rotation-dev-*` (1-day retention) |
