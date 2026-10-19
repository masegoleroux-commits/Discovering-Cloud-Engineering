# 0003 HTTP API instead of REST API

Status: Accepted

## Context
API Gateway offers two styles: HTTP APIs and REST APIs.

## Decision
Use an HTTP API.

## Alternatives rejected
- **REST API:** adds features this project doesn't need (usage plans, API keys, request validation models) and costs more per request.

## Consequences
Simpler configuration and lower cost. If I need API keys and quotas later, as in project 02, I'd switch to a REST API.
