"""Test cases for the safe responder (TC-15-U09 to U13)."""
import boto3
from moto import mock_aws

from conftest import cloudtrail_event, load, sg_rule

resp = load("responder")


def make_open_group(ec2):
    vpc = ec2.create_vpc(CidrBlock="10.70.0.0/16")["Vpc"]["VpcId"]
    sg = ec2.create_security_group(GroupName="canary", Description="test", VpcId=vpc)["GroupId"]
    ec2.authorize_security_group_ingress(GroupId=sg, IpPermissions=[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}])
    return sg


def test_open_group_is_tagged_but_rule_is_kept():
    """TC-15-U09: a group opened to the internet gets the SecurityFinding tag, and the rule is NOT removed."""
    with mock_aws():
        ec2 = boto3.client("ec2")
        sg = make_open_group(ec2)
        result = resp.lambda_handler(cloudtrail_event(group=sg), None)
        assert result["done"] is True
        group = ec2.describe_security_groups(GroupIds=[sg])["SecurityGroups"][0]
        tags = {t["Key"]: t["Value"] for t in group.get("Tags", [])}
        assert tags["SecurityFinding"].startswith("open-to-internet 2026-10-27T10:00:00Z")
        assert any(r.get("CidrIp") == "0.0.0.0/0" for p in group["IpPermissions"] for r in p["IpRanges"])  # tagged, never revoked


def test_ipv6_open_group_is_tagged_too():
    """TC-15-U10: ::/0 counts as open to the internet."""
    req = {"groupId": "sg-1", "ipPermissions": {"items": [sg_rule(cidr=None, ipv6="::/0")]}}
    assert resp.plan_action(cloudtrail_event(request=req)["detail"])["action"] == "tag_security_group"


def test_failed_calls_change_nothing():
    """TC-15-U11: a call that failed (for example AccessDenied) makes no AWS call at all."""
    calls = []
    real = resp.boto3.client
    resp.boto3.client = lambda *a, **k: calls.append(a) or real(*a, **k)
    try:
        result = resp.lambda_handler(cloudtrail_event(error="UnauthorizedOperation"), None)
    finally:
        resp.boto3.client = real
    assert result["done"] is False and calls == [] and "failed" in result["planned"]["reason"]


def test_private_rules_are_ignored():
    """TC-15-U12: a rule from a private range (not the internet) is left alone."""
    req = {"groupId": "sg-1", "ipPermissions": {"items": [sg_rule(cidr="10.0.0.0/16")]}}
    assert resp.plan_action(cloudtrail_event(request=req)["detail"])["action"] == "none"


def test_other_events_are_left_for_a_person():
    """TC-15-U13: trail and bucket events are reported by email but never acted on automatically."""
    for name in ("StopLogging", "DeleteTrail", "DeleteBucketPublicAccessBlock"):
        plan = resp.plan_action(cloudtrail_event(name=name, request={"name": "t"})["detail"])
        assert plan["action"] == "none" and "left for a person" in plan["reason"]
