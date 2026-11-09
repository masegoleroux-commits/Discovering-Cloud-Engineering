# 0003 Test with AWS sample findings

Status: Accepted

## Context
I need findings to test the pipeline, without attacking anything.

## Decision
Use `create-sample-findings`. The formatter puts `[SAMPLE]` in the subject and body.

## Alternatives rejected
- **Simulate an attack (port scans, fake credentials):** risky, against AWS policy without care, and not needed to test the pipeline.

## Consequences
Every screenshot and email is clearly labelled as a sample.
