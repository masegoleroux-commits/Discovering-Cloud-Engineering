# 0002 Keep the previous key valid until the next rotation

Status: Accepted

## Context
Clients cache the key for up to 5 minutes. Revoking the old key the moment a new one is current would break them.

## Decision
At `finishSecret`, revoke only the key from two rotations ago. Current and previous both stay valid.

## Alternatives rejected
- **Revoke the old key immediately:** simplest, but any client with a cached key fails until its cache expires.
- **Never revoke:** a leaked key would stay valid forever, which defeats rotation.

## Consequences
A leaked key is valid for at most two rotation periods (14 days by default). Proved by TC-13-L04 and TC-13-L06.
