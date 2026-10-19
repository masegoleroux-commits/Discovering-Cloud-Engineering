# 0004 Never retry validation errors

Status: Accepted

## Context
Step Functions can retry any failed task.

## Decision
Retry only temporary Lambda service errors, at most 2 times. `ValidationError` goes straight to the dead-letter queue.

## Alternatives rejected
- **Retry everything:** a bad file is still bad on the second try, and each retry is another paid Lambda call that delays the alert.

## Consequences
Failures surface in seconds, and a bad file can never loop and get the function deleted.
