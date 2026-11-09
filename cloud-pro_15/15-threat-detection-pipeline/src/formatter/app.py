"""Turns a risky CloudTrail event (delivered by EventBridge) into a short, readable email via SNS.

The events come from three EventBridge rules: a new inbound security-group rule (only
rules open to the whole internet become alerts),
CloudTrail logging stopped or a trail deleted, and an S3 bucket's Block Public Access removed.
Alerts about the project's own test security group are labelled DELIBERATE TEST.
"""
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

MAX_SUBJECT = 100  # SNS email subjects must be under 100 characters
WORLD = {"0.0.0.0/0", "::/0"}


def permissions(request: dict) -> list:
    """The rules in an AuthorizeSecurityGroupIngress call, in one shape.

    CloudTrail records them in two ways: nested under ipPermissions.items (console,
    Terraform, --ip-permissions), or as flat fields (cidrIp, ipProtocol, fromPort, toPort)
    when the short CLI form --protocol/--port/--cidr is used.
    """
    perms = list((request.get("ipPermissions") or {}).get("items", []) or [])
    if request.get("cidrIp") or request.get("cidrIpv6"):
        flat = {"ipProtocol": request.get("ipProtocol", "-1"), "fromPort": request.get("fromPort"), "toPort": request.get("toPort")}
        if request.get("cidrIp"):
            flat["ipRanges"] = {"items": [{"cidrIp": request["cidrIp"]}]}
        if request.get("cidrIpv6"):
            flat["ipv6Ranges"] = {"items": [{"cidrIpv6": request["cidrIpv6"]}]}
        perms.append(flat)
    return perms


def world_open_ports(request: dict) -> list:
    """List the rules in an AuthorizeSecurityGroupIngress call that are open to the whole internet."""
    found = []
    for perm in permissions(request):
        sources = [r.get("cidrIp") for r in (perm.get("ipRanges") or {}).get("items", []) or []]
        sources += [r.get("cidrIpv6") for r in (perm.get("ipv6Ranges") or {}).get("items", []) or []]
        for cidr in sources:
            if cidr in WORLD:
                proto = str(perm.get("ipProtocol", "?"))
                if proto in ("-1", "all"):
                    found.append(f"ALL traffic from {cidr}")
                else:
                    lo, hi = perm.get("fromPort"), perm.get("toPort")
                    ports = f"port {lo}" if lo == hi else f"ports {lo}-{hi}"
                    found.append(f"{proto.upper()} {ports} from {cidr}")
    return found


def describe(detail: dict) -> dict:
    """What happened, how serious it is, which resource, and what to do."""
    name = detail.get("eventName", "Unknown")
    req = detail.get("requestParameters") or {}
    if name == "AuthorizeSecurityGroupIngress":
        group = req.get("groupId", req.get("groupName", "?"))
        rules = world_open_ports(req)
        all_traffic = any(r.startswith("ALL") for r in rules)
        return {
            "severity": "CRITICAL" if all_traffic else "HIGH",
            "what": f"Security group {group} was opened to the internet: {'; '.join(rules) or 'rule open to anywhere'}",
            "resource": group,
            "todo": "Check who made this change and why. If it isn't needed, remove the rule (EC2 -> Security groups).",
        }
    if name in ("StopLogging", "DeleteTrail"):
        trail = req.get("name", "?")
        verb = "stopped logging" if name == "StopLogging" else "was deleted"
        return {
            "severity": "CRITICAL",
            "what": f"CloudTrail trail {trail} {verb}: API calls are no longer being recorded",
            "resource": trail,
            "todo": "Turn logging back on unless this was a planned change. Attackers do this to hide what comes next.",
        }
    if name == "DeleteBucketPublicAccessBlock":
        bucket = req.get("bucketName", "?")
        return {
            "severity": "HIGH",
            "what": f"S3 bucket {bucket} had its Block Public Access settings removed",
            "resource": bucket,
            "todo": "Check the bucket's policy and ACLs for public access, and put the block back if it isn't a public website.",
        }
    return {"severity": "MEDIUM", "what": f"Risky API call: {name}", "resource": "?", "todo": "Investigate in CloudTrail event history."}


def build_message(detail: dict, test_sg_id: str = "") -> tuple:
    info = describe(detail)
    failed = detail.get("errorCode")
    deliberate = bool(test_sg_id) and info["resource"] == test_sg_id
    severity = "LOW" if failed else info["severity"]
    prefix = "[DELIBERATE TEST] " if deliberate else ""
    outcome = " (attempt FAILED)" if failed else ""
    subject = f"{prefix}{severity}: {detail.get('eventName', 'Unknown')} {info['resource']}{outcome}"
    if len(subject) > MAX_SUBJECT:
        subject = subject[: MAX_SUBJECT - 3] + "..."
    who = detail.get("userIdentity", {}) or {}
    lines = [
        "DELIBERATE TEST: this change was made on purpose by run_tests.sh on a harmless test security group." if deliberate
        else "Real event recorded by CloudTrail in this account.",
        "",
        f"What:     {info['what']}",
        f"Severity: {severity}" + (f" (the call failed with {failed}, so nothing changed)" if failed else ""),
        f"Who:      {who.get('arn', who.get('type', '?'))}",
        f"From IP:  {detail.get('sourceIPAddress', '?')}",
        f"Where:    {detail.get('awsRegion', '?')}, account {detail.get('recipientAccountId', '?')}",
        f"When:     {detail.get('eventTime', '?')}",
        "",
        f"What to do: {info['todo']}",
        f"CloudTrail event ID: {detail.get('eventID', '?')}",
    ]
    return subject, "\n".join(lines)


def needs_alert(detail: dict) -> bool:
    """The security-group rule sends every new inbound rule; only internet-wide ones are alerts."""
    if detail.get("eventName") == "AuthorizeSecurityGroupIngress":
        return bool(world_open_ports(detail.get("requestParameters") or {}))
    return True


def lambda_handler(event, context):
    detail = event["detail"]
    if not needs_alert(detail):
        logger.info(json.dumps({"event_id": detail.get("eventID"), "event": detail.get("eventName"), "skipped": "rule isn't open to the internet",
                                "requestParameters": detail.get("requestParameters")}))
        return {"skipped": True}
    subject, message = build_message(detail, os.environ.get("TEST_SG_ID", ""))
    boto3.client("sns").publish(TopicArn=os.environ["TOPIC_ARN"], Subject=subject, Message=message)
    logger.info(json.dumps({"event_id": detail.get("eventID"), "event": detail.get("eventName"), "subject": subject}))
    return {"subject": subject}
