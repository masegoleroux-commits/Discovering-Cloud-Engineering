# 0003 Multi-region trail

Status: Accepted

## Context
A trail can record one region or all of them. Attackers often launch resources in regions an account never uses, hoping nobody looks there.

## Decision
Record every region (`multi_region_trail = true`).

## Alternatives rejected
- **Single-region trail:** misses activity everywhere except the home region (eu-north-1).

## Consequences
The first copy of management events in each region is free, so this costs nothing extra. Logs from all regions land in the same bucket and log group. In an AWS Organization I would use an organisation trail instead.
