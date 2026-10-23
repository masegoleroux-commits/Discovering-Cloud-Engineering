# 0001 CloudFront in front, WAF on the load balancer

Status: Accepted

## Context
The site needs HTTPS, protection from floods and common attacks, and a single entry point. My AWS account only allows the eu-north-1 region, and a WAF attached to CloudFront must be created in us-east-1.

## Decision
Put CloudFront in front of the ALB, and attach a REGIONAL AWS WAF web ACL to the ALB in eu-north-1. Its rate limit counts the real visitor IP from the `X-Forwarded-For` header CloudFront adds. A `waf_scope = "CLOUDFRONT"` switch moves the web ACL onto CloudFront for accounts that allow us-east-1.

## Alternatives rejected
- **WAF on CloudFront:** filters traffic at the edge, closest to the attacker, which is the better design, but it can't be created in a single-region account.
- **No WAF:** rate limiting and attack filtering would have to be written into the application.

## Consequences
Bad requests are still blocked before reaching a server, but they travel to the region first, so CloudFront and the ALB handle them. `X-Forwarded-For` can be partly set by the client; CloudFront appends the real address, but WAF reads the first one, so a determined attacker could spread requests across fake addresses. On CloudFront scope this weakness disappears. WAF adds about $8/month in fixed charges, prorated, which is why the project is torn down after each session.
