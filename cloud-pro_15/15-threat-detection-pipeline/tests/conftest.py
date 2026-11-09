import importlib.util
import sys
from pathlib import Path

import pytest

SRC = Path(__file__).resolve().parent.parent / "src"


def load(name):
    spec = importlib.util.spec_from_file_location(f"{name}_app", SRC / name / "app.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[f"{name}_app"] = module
    spec.loader.exec_module(module)
    return module


def sg_rule(proto="tcp", port=22, cidr="0.0.0.0/0", ipv6=None, to_port=None):
    """One ipPermissions item, shaped like CloudTrail records it for AuthorizeSecurityGroupIngress."""
    item = {"ipProtocol": proto, "groups": {}, "prefixListIds": {}, "ipRanges": {}, "ipv6Ranges": {}}
    if proto != "-1":
        item["fromPort"] = port
        item["toPort"] = to_port if to_port is not None else port
    if cidr:
        item["ipRanges"] = {"items": [{"cidrIp": cidr}]}
    if ipv6:
        item["ipv6Ranges"] = {"items": [{"cidrIpv6": ipv6}]}
    return item


def cloudtrail_event(name="AuthorizeSecurityGroupIngress", request=None, error=None, **extra):
    """An EventBridge 'AWS API Call via CloudTrail' event with the fields the functions use."""
    if request is None and name == "AuthorizeSecurityGroupIngress":
        request = {"groupId": extra.get("group", "sg-0123456789abcdef0"), "ipPermissions": {"items": [sg_rule()]}}
    detail = {
        "eventVersion": "1.10",
        "eventSource": extra.get("source", "ec2.amazonaws.com"),
        "eventName": name,
        "eventTime": "2026-10-27T10:00:00Z",
        "eventID": "11111111-2222-3333-4444-555555555555",
        "awsRegion": "eu-north-1",
        "recipientAccountId": "123456789012",
        "sourceIPAddress": "203.0.113.7",
        "userIdentity": {"type": "IAMUser", "arn": "arn:aws:iam::123456789012:user/masego-admin"},
        "requestParameters": request or {},
    }
    if error:
        detail["errorCode"] = error
    return {"detail-type": "AWS API Call via CloudTrail", "source": "aws.ec2", "detail": detail}


@pytest.fixture(autouse=True)
def aws_env(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-north-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
