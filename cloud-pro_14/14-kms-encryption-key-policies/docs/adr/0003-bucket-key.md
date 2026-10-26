# 0003 S3 Bucket Keys and a deny-unencrypted bucket policy

Status: Accepted

## Context
Every S3 request with SSE-KMS calls KMS, which costs money and can hit request limits.

## Decision
Turn on S3 Bucket Keys, and refuse uploads that don't use this key.

## Alternatives rejected
- **SSE-S3 (AES256):** cheaper, but no key policy to control who decrypts.

## Consequences
Far fewer KMS calls; no object can be stored unencrypted or under another key.
