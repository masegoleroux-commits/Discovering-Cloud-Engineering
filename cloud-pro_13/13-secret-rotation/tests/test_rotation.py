"""Test cases for the four rotation steps (TC-13-U01 to U08). No AWS account needed."""
import hashlib
import uuid

import pytest

from conftest import load

rotation = load("rotation")
api = load("api")


def h(key):
    return hashlib.sha256(key.encode()).hexdigest()


def make_secret(sm, table, first_key="first-key-000"):
    """A secret with one AWSCURRENT version, registered in the registry like Terraform does."""
    arn = sm.create_secret(Name="partner-api-key", SecretString=first_key)["ARN"]
    v1 = sm.describe_secret(SecretId=arn)["VersionIdsToStages"]
    v1 = next(v for v, s in v1.items() if "AWSCURRENT" in s)
    table.put_item(Item={"key_hash": h(first_key), "version_id": v1})
    return arn, v1


def api_says(monkeypatch, table):
    """Make the rotation's API test call the real API handler against the mocked registry."""
    monkeypatch.setattr(rotation, "invoke_api", lambda key: api.lambda_handler({"api_key": key}, None)["statusCode"])


def rotate(sm, table, arn):
    token = str(uuid.uuid4())
    rotation.create_secret(sm, table, arn, token)
    rotation.set_secret(sm, table, arn, token)
    rotation.test_secret(sm, table, arn, token)
    rotation.finish_secret(sm, table, arn, token)
    return token


def current_value(sm, arn):
    return sm.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")["SecretString"]


def test_create_stores_new_key_as_pending(aws):
    """TC-13-U01: createSecret stores a NEW 40-character key as AWSPENDING."""
    sm, table = aws
    arn, _ = make_secret(sm, table)
    token = str(uuid.uuid4())
    rotation.create_secret(sm, table, arn, token)
    pending = sm.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")["SecretString"]
    assert len(pending) == 40 and pending != "first-key-000"
    assert current_value(sm, arn) == "first-key-000"  # nothing switched yet


def test_create_is_idempotent(aws):
    """TC-13-U02: a retried createSecret does not generate a second, different key."""
    sm, table = aws
    arn, _ = make_secret(sm, table)
    token = str(uuid.uuid4())
    rotation.create_secret(sm, table, arn, token)
    first = sm.get_secret_value(SecretId=arn, VersionId=token)["SecretString"]
    rotation.create_secret(sm, table, arn, token)
    assert sm.get_secret_value(SecretId=arn, VersionId=token)["SecretString"] == first


def test_set_registers_hash_not_plaintext(aws):
    """TC-13-U03: setSecret registers only the SHA-256 hash of the new key."""
    sm, table = aws
    arn, _ = make_secret(sm, table)
    token = str(uuid.uuid4())
    rotation.create_secret(sm, table, arn, token)
    rotation.set_secret(sm, table, arn, token)
    pending = sm.get_secret_value(SecretId=arn, VersionId=token)["SecretString"]
    items = table.scan()["Items"]
    assert {"key_hash": h(pending), "version_id": token} in items
    assert all(pending not in str(i) for i in items)


def test_test_step_blocks_a_bad_key(aws, monkeypatch):
    """TC-13-U04: if the API rejects the new key, rotation stops and the old key stays current."""
    sm, table = aws
    arn, _ = make_secret(sm, table)
    token = str(uuid.uuid4())
    rotation.create_secret(sm, table, arn, token)
    # setSecret deliberately skipped: the API has never heard of the new key
    api_says(monkeypatch, table)
    with pytest.raises(RuntimeError, match="rejected"):
        rotation.test_secret(sm, table, arn, token)
    assert current_value(sm, arn) == "first-key-000"


def test_full_rotation_switches_key_and_keeps_previous_valid(aws, monkeypatch):
    """TC-13-U05: after one rotation the new key is current AND the old key still works."""
    sm, table = aws
    arn, _ = make_secret(sm, table)
    api_says(monkeypatch, table)
    rotate(sm, table, arn)
    new_key = current_value(sm, arn)
    assert new_key != "first-key-000"
    assert api.lambda_handler({"api_key": new_key}, None)["statusCode"] == 200
    assert api.lambda_handler({"api_key": "first-key-000"}, None)["statusCode"] == 200  # cached clients keep working


def test_second_rotation_revokes_the_oldest_key(aws, monkeypatch):
    """TC-13-U06: after two rotations, the first key is revoked; only current and previous work."""
    sm, table = aws
    arn, _ = make_secret(sm, table)
    api_says(monkeypatch, table)
    rotate(sm, table, arn)
    second_key = current_value(sm, arn)
    rotate(sm, table, arn)
    third_key = current_value(sm, arn)
    assert api.lambda_handler({"api_key": "first-key-000"}, None)["statusCode"] == 403
    assert api.lambda_handler({"api_key": second_key}, None)["statusCode"] == 200
    assert api.lambda_handler({"api_key": third_key}, None)["statusCode"] == 200
    assert len(table.scan()["Items"]) == 2


def test_handler_refuses_unknown_step(aws, monkeypatch):
    """TC-13-U07: an unknown step name is refused."""
    sm, table = aws
    arn, _ = make_secret(sm, table)
    token = str(uuid.uuid4())
    sm.put_secret_value(SecretId=arn, ClientRequestToken=token, SecretString="x" * 40, VersionStages=["AWSPENDING"])
    real_describe = sm.describe_secret
    monkeypatch.setattr(rotation, "_clients", lambda: (sm, table))
    monkeypatch.setattr(sm, "describe_secret", lambda **kw: {**real_describe(**kw), "RotationEnabled": True})
    with pytest.raises(ValueError, match="Unknown rotation step"):
        rotation.lambda_handler({"SecretId": arn, "ClientRequestToken": token, "Step": "deleteEverything"}, None)


def test_handler_refuses_when_rotation_disabled(aws, monkeypatch):
    """TC-13-U08: the function refuses to run for a secret that doesn't have rotation enabled."""
    sm, table = aws
    arn, v1 = make_secret(sm, table)
    monkeypatch.setattr(rotation, "_clients", lambda: (sm, table))
    with pytest.raises(ValueError, match="not enabled"):
        rotation.lambda_handler({"SecretId": arn, "ClientRequestToken": v1, "Step": "createSecret"}, None)
