# 0001 Session Manager instead of SSH

Status: Accepted

## Context
The server needs administration access. SSH needs port 22 open and key pairs to manage.

## Decision
Use AWS Systems Manager Session Manager. No inbound admin port and no key pair.

## Alternatives rejected
- **SSH from anywhere:** the most scanned port on the internet.
- **SSH via a bastion host:** another instance to patch and pay for, and keys still to manage.
- **EC2 Instance Connect:** still needs port 22 open.

## Consequences
Access is controlled by IAM, and sessions can be logged. It depends on the SSM agent and outbound HTTPS. If Session Manager ever can't connect, the documented fallback opens SSH to a single IP only; record here whether that was needed.
