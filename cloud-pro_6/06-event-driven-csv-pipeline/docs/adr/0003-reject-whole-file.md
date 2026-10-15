# 0003 Reject the whole file

Status: Accepted

## Context
A file can contain a mix of good and bad rows.

## Decision
If any row is invalid, reject the whole file and load nothing.

## Alternatives rejected
- **Load good rows, report bad rows:** leaves partial data that someone must reconcile later.

## Consequences
Simple to reason about: a file is either fully loaded or fully rejected. The sender must fix and resend the whole file.
