"""Test cases for the alert formatter (TC-15-U01 to U08, U14)."""
import boto3
from moto import mock_aws

from conftest import cloudtrail_event, load, sg_rule

fmt = load("formatter")


def test_open_ssh_is_high_and_names_the_rule():
    """TC-15-U01: port 22 opened to 0.0.0.0/0 is HIGH, and the email names the port and the group."""
    subject, body = fmt.build_message(cloudtrail_event()["detail"])
    assert subject.startswith("HIGH: AuthorizeSecurityGroupIngress sg-0123456789abcdef0")
    assert "TCP port 22 from 0.0.0.0/0" in body and "masego-admin" in body and "203.0.113.7" in body


def test_all_traffic_and_ipv6_are_detected():
    """TC-15-U02: 'all traffic' is CRITICAL, and IPv6 ::/0 and port ranges are reported too."""
    req = {"groupId": "sg-1", "ipPermissions": {"items": [sg_rule(proto="-1", cidr="0.0.0.0/0"), sg_rule(port=8000, to_port=8100, cidr=None, ipv6="::/0")]}}
    subject, body = fmt.build_message(cloudtrail_event(request=req)["detail"])
    assert subject.startswith("CRITICAL:")
    assert "ALL traffic from 0.0.0.0/0" in body and "TCP ports 8000-8100 from ::/0" in body


def test_stopping_the_audit_trail_is_critical():
    """TC-15-U03: StopLogging and DeleteTrail are CRITICAL and name the trail."""
    for name in ("StopLogging", "DeleteTrail"):
        subject, body = fmt.build_message(cloudtrail_event(name=name, request={"name": "my-trail"}, source="cloudtrail.amazonaws.com")["detail"])
        assert subject.startswith(f"CRITICAL: {name} my-trail") and "no longer being recorded" in body


def test_removed_bucket_block_is_high():
    """TC-15-U04: removing a bucket's Block Public Access is HIGH and names the bucket."""
    subject, _ = fmt.build_message(cloudtrail_event(name="DeleteBucketPublicAccessBlock", request={"bucketName": "photos"}, source="s3.amazonaws.com")["detail"])
    assert subject.startswith("HIGH: DeleteBucketPublicAccessBlock photos")


def test_deliberate_test_is_labelled_and_failed_calls_are_low():
    """TC-15-U05: alerts about the test group say DELIBERATE TEST; failed calls are LOW and say nothing changed."""
    subject, body = fmt.build_message(cloudtrail_event(group="sg-test")["detail"], test_sg_id="sg-test")
    assert subject.startswith("[DELIBERATE TEST] HIGH:") and "made on purpose by run_tests.sh" in body
    subject, body = fmt.build_message(cloudtrail_event(error="UnauthorizedOperation")["detail"])
    assert subject.startswith("LOW:") and "(attempt FAILED)" in subject and "nothing changed" in body
    assert "DELIBERATE" not in fmt.build_message(cloudtrail_event()["detail"], test_sg_id="sg-other")[0]


def test_subject_fits_email_limit():
    """TC-15-U06: a very long resource name is cut so the subject stays within 100 characters."""
    subject, _ = fmt.build_message(cloudtrail_event(name="DeleteBucketPublicAccessBlock", request={"bucketName": "b" * 300}, source="s3.amazonaws.com")["detail"])
    assert len(subject) <= 100 and subject.endswith("...")


def test_handler_publishes_one_message(monkeypatch):
    """TC-15-U07: the handler publishes exactly one message to the topic."""
    with mock_aws():
        topic = boto3.client("sns").create_topic(Name="alerts")["TopicArn"]
        monkeypatch.setenv("TOPIC_ARN", topic)
        monkeypatch.setenv("TEST_SG_ID", "sg-0123456789abcdef0")
        published = []
        real = fmt.boto3.client

        def spy(service, *a, **kw):
            c = real(service, *a, **kw)
            orig = c.publish
            c.publish = lambda **k: published.append(k) or orig(**k)
            return c

        monkeypatch.setattr(fmt.boto3, "client", spy)
        result = fmt.lambda_handler(cloudtrail_event(), None)
        assert len(published) == 1 and published[0]["TopicArn"] == topic
        assert result["subject"].startswith("[DELIBERATE TEST] HIGH")


def test_private_rules_send_no_email(monkeypatch):
    """TC-15-U08: a new rule from a private range sends no email; one open to the internet does."""
    sent = []
    monkeypatch.setenv("TOPIC_ARN", "arn:aws:sns:eu-north-1:123456789012:alerts")
    monkeypatch.setattr(fmt.boto3, "client", lambda *a, **k: type("C", (), {"publish": lambda self, **kw: sent.append(kw)})())
    req = {"groupId": "sg-1", "ipPermissions": {"items": [sg_rule(cidr="10.0.0.0/16")]}}
    assert fmt.lambda_handler(cloudtrail_event(request=req), None) == {"skipped": True} and sent == []
    req = {"groupId": "sg-1", "ipPermissions": {"items": [sg_rule(cidr="10.0.0.0/16"), sg_rule(port=443)]}}
    fmt.lambda_handler(cloudtrail_event(request=req), None)
    assert len(sent) == 1 and "TCP port 443 from 0.0.0.0/0" in sent[0]["Message"]


def test_short_cli_form_is_detected_too():
    """TC-15-U14: the flat form CloudTrail uses for `--protocol tcp --port 22 --cidr 0.0.0.0/0` is detected by both functions."""
    flat = {"groupId": "sg-1", "ipProtocol": "tcp", "fromPort": 22, "toPort": 22, "cidrIp": "0.0.0.0/0"}
    subject, body = fmt.build_message(cloudtrail_event(request=flat)["detail"])
    assert subject.startswith("HIGH: AuthorizeSecurityGroupIngress sg-1") and "TCP port 22 from 0.0.0.0/0" in body
    assert fmt.needs_alert(cloudtrail_event(request=flat)["detail"]) is True
    assert fmt.needs_alert(cloudtrail_event(request=dict(flat, cidrIp="10.0.0.0/8"))["detail"]) is False
    resp = load("responder")
    assert resp.plan_action(cloudtrail_event(request=flat)["detail"])["action"] == "tag_security_group"
    assert resp.plan_action(cloudtrail_event(request=dict(flat, cidrIp="10.0.0.0/8"))["detail"])["action"] == "none"
