# 0002 Separate key administrators from key users

Status: Accepted

## Context
People who manage keys shouldn't be able to read the data those keys protect.

## Decision
The key-admin role gets management actions listed one by one; only the app role gets Encrypt/Decrypt.

## Alternatives rejected
- **`kms:*` for admins:** includes Decrypt.
- **`kms:Create*` and `kms:PutKeyPolicy` for admins:** CreateGrant or a policy rewrite would let an admin give themselves Decrypt.

## Consequences
Proved by TC-14-L03 (admin refused) and TC-14-L05 (admin can't grant themselves access). The account root statement stays, so the key can never become unmanageable; that's also why an AdministratorAccess user can still decrypt.
