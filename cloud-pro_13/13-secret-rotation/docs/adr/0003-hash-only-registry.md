# 0003 Store only key hashes in the registry

Status: Accepted

## Context
The registry must check keys, but a copy of every key in a table would be a second place to leak them.

## Decision
Store the SHA-256 hash of each key; the API hashes what it receives and compares.

## Alternatives rejected
- **Store the plain key:** anyone who can read the table could use every key.

## Consequences
Reading the table gives nothing usable. Proved by TC-13-U03 and TC-13-L09.
