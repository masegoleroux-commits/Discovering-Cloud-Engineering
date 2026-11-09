"""Safe automated response: TAGS a security group that was opened to the internet.

It never removes the rule, stops, changes or deletes anything (ADR 0001): a person decides.
Failed API calls, rules that aren't open to the internet, and every other event type are
logged and left alone.
"""
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

TAG_KEY = "SecurityFinding"
WORLD = {"0.0.0.0/0", "::/0"}


def is_open_to_world(request: dict) -> bool:
    # Short CLI form (--protocol/--port/--cidr): CloudTrail records flat fields
    if request.get("cidrIp") in WORLD or request.get("cidrIpv6") in WORLD:
        return True
    # Console, Terraform and --ip-permissions: nested under ipPermissions.items
    for perm in (request.get("ipPermissions") or {}).get("items", []) or []:
        for r in (perm.get("ipRanges") or {}).get("items", []) or []:
            if r.get("cidrIp") in WORLD:
                return True
        for r in (perm.get("ipv6Ranges") or {}).get("items", []) or []:
            if r.get("cidrIpv6") in WORLD:
                return True
    return False


def plan_action(detail: dict) -> dict:
    """Decide what to tag. Returns {"action": ..., "target": ..., "reason": ...}."""
    if detail.get("errorCode"):
        return {"action": "none", "target": None, "reason": f"call failed ({detail['errorCode']}), nothing changed"}
    if detail.get("eventName") != "AuthorizeSecurityGroupIngress":
        return {"action": "none", "target": None, "reason": "left for a person (only security groups are tagged)"}
    req = detail.get("requestParameters") or {}
    group = req.get("groupId")
    if not group:
        return {"action": "none", "target": None, "reason": "no security group ID in the event"}
    if not is_open_to_world(req):
        return {"action": "none", "target": None, "reason": "rule isn't open to the internet"}
    return {"action": "tag_security_group", "target": group, "reason": "opened to the internet"}


def lambda_handler(event, context):
    detail = event["detail"]
    plan = plan_action(detail)
    if plan["action"] == "tag_security_group":
        value = f"open-to-internet {detail.get('eventTime', '')} event {detail.get('eventID', '')}"[:256]
        boto3.client("ec2").create_tags(Resources=[plan["target"]], Tags=[{"Key": TAG_KEY, "Value": value}])
    done = plan["action"] != "none"
    logger.info(json.dumps({"event_id": detail.get("eventID"), "event": detail.get("eventName"), "planned": plan, "done": done,
                            "requestParameters": detail.get("requestParameters") if not done else None}))
    return {"planned": plan, "done": done}
