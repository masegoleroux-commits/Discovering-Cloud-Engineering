# 0001 Step Functions instead of chained Lambdas

Status: Accepted

## Context
Validation and loading are two steps, and failures need retries and routing.

## Decision
Orchestrate the steps with a Step Functions Standard workflow.

## Alternatives rejected
- **Validate Lambda calls the load Lambda directly:** retry and error-routing logic would live in my code, and there would be no visual history of each run.
- **Express workflow:** cheaper at high volume but keeps less execution history; volume here is tiny.

## Consequences
Retries, catches and a per-execution audit trail come built in. Every state transition is logged, so any run can be replayed and explained.
