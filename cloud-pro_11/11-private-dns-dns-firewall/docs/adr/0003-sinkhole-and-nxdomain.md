# 0003 Sinkhole as well as NXDOMAIN

Status: Accepted

## Context
Blocked lookups can either fail (NXDOMAIN) or be redirected (override).

## Decision
Use NXDOMAIN for unwanted-but-harmless domains (ad tracking), and a sinkhole override for domains that suggest compromise.

## Alternatives rejected
- **NXDOMAIN for everything:** simple, but an infected host just fails silently and is hard to find.

## Consequences
Connections to the sinkhole address can be spotted in Flow Logs or by a listener, pointing straight at the infected machine. I use 192.0.2.1, a reserved documentation address, so nothing real is ever reached.
