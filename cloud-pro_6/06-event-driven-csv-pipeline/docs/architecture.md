# Architecture

```mermaid
flowchart LR
  U[Upload to incoming/] --> S3[(S3 uploads bucket)]
  S3 -->|Object Created| EB[EventBridge rule]
  EB -->|StartExecution| SF[Step Functions]
  SF --> V[Lambda validate]
  V -->|valid| L[Lambda load]
  L --> DB[(DynamoDB orders)]
  L --> OK[SNS success email]
  V -->|ValidationError| DLQ[(SQS dead-letter queue)]
  L -->|any error| DLQ
  DLQ --> BAD[SNS rejection email]
```

## Workflow states

```mermaid
stateDiagram-v2
  [*] --> ValidateFile
  ValidateFile --> LoadOrders: valid
  ValidateFile --> SendToDeadLetterQueue: error (caught)
  LoadOrders --> NotifySuccess: loaded
  LoadOrders --> SendToDeadLetterQueue: error (caught)
  NotifySuccess --> [*]
  SendToDeadLetterQueue --> NotifyFailure
  NotifyFailure --> MarkFailed
  MarkFailed --> [*]
```

Each task adds its result under its own field (`ResultPath`), so `bucket` and `key` from the original input stay available in every later state.

| Component | AWS name |
|-----------|----------|
| Upload bucket | `csv-pipeline-dev-uploads-<account_id>` |
| EventBridge rule | `csv-pipeline-dev-csv-uploaded` |
| State machine | `csv-pipeline-dev-pipeline` |
| Lambdas | `csv-pipeline-dev-validate`, `csv-pipeline-dev-load` |
| Table | `csv-pipeline-dev-orders` |
| Dead-letter queue | `csv-pipeline-dev-failed` |
| SNS topic | `csv-pipeline-dev-notifications` |
