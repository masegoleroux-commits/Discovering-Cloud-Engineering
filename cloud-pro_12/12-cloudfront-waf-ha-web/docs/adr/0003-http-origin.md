# 0003 HTTP between CloudFront and the ALB

Status: Accepted

## Context
Visitors connect to CloudFront over HTTPS. The CloudFront-to-ALB leg could be HTTP or HTTPS.

## Decision
Use HTTP to the origin.

## Alternatives rejected
- **HTTPS to the origin:** the right production choice, but it needs a certificate for a domain I own on the ALB. CloudFront won't accept the ALB's own `*.elb.amazonaws.com` name for HTTPS origins with a valid certificate.

## Consequences
Traffic between CloudFront and the ALB, including the secret header, is unencrypted over the internet. Acceptable for a portfolio project with no real data; with a domain I'd add an ACM certificate to the ALB and switch to `https-only`.
