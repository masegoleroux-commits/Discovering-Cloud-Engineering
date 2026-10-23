"""Secrets Manager rotation function for a partner API key.

Secrets Manager calls this function four times per rotation, once per step:
  createSecret -> setSecret -> testSecret -> finishSecret

The "partner system" is a DynamoDB key registry that stores only SHA-256 hashes
of valid keys, never the keys themselves. The previous key stays valid until the
next rotation, so a client holding a cached key never fails mid-rotation.
"""
import hashlib
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

KEY_LENGTH = 40


def _clients():
    return boto3.client("secretsmanager"), boto3.resource("dynamodb").Table(os.environ["REGISTRY_TABLE"])


def key_hash(key: str) -> str:
    return hashlib.sha256(key.encode("utf-8")).hexdigest()


def invoke_api(api_key: str) -> int:
    """Ask the demo API whether it accepts this key. Returns the HTTP-style status code."""
    response = boto3.client("lambda").invoke(
        FunctionName=os.environ["API_FUNCTION"],
        Payload=json.dumps({"api_key": api_key}).encode("utf-8"),
    )
    return json.loads(response["Payload"].read())["statusCode"]


def lambda_handler(event, context):
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]
    sm, table = _clients()

    metadata = sm.describe_secret(SecretId=arn)
    if not metadata.get("RotationEnabled"):
        raise ValueError(f"Rotation is not enabled for {arn}")
    versions = metadata["VersionIdsToStages"]
    if token not in versions:
        raise ValueError(f"Version {token} has no stage for rotation of {arn}")
    if "AWSCURRENT" in versions[token]:
        logger.info(json.dumps({"step": step, "msg": "version already AWSCURRENT, nothing to do"}))
        return
    if "AWSPENDING" not in versions[token]:
        raise ValueError(f"Version {token} is not set as AWSPENDING for rotation of {arn}")

    steps = {
        "createSecret": create_secret,
        "setSecret": set_secret,
        "testSecret": test_secret,
        "finishSecret": finish_secret,
    }
    if step not in steps:
        raise ValueError(f"Unknown rotation step: {step}")
    steps[step](sm, table, arn, token)
    logger.info(json.dumps({"step": step, "version": token, "result": "ok"}))


def create_secret(sm, table, arn, token):
    """Generate the new key and store it as AWSPENDING (idempotent)."""
    try:
        sm.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        return  # already created by an earlier attempt
    except sm.exceptions.ResourceNotFoundException:
        pass
    new_key = sm.get_random_password(PasswordLength=KEY_LENGTH, ExcludePunctuation=True)["RandomPassword"]
    sm.put_secret_value(SecretId=arn, ClientRequestToken=token, SecretString=new_key, VersionStages=["AWSPENDING"])


def set_secret(sm, table, arn, token):
    """Register the new key with the partner system (by hash only)."""
    pending = sm.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")["SecretString"]
    table.put_item(Item={"key_hash": key_hash(pending), "version_id": token})


def test_secret(sm, table, arn, token):
    """Prove the new key works BEFORE it becomes current."""
    pending = sm.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")["SecretString"]
    status = invoke_api(pending)
    if status != 200:
        raise RuntimeError(f"New key was rejected by the API (status {status}); rotation stopped")


def finish_secret(sm, table, arn, token):
    """Make the new key current and revoke anything older than the previous key."""
    versions = sm.describe_secret(SecretId=arn)["VersionIdsToStages"]
    current = next((v for v, stages in versions.items() if "AWSCURRENT" in stages), None)
    if current == token:
        return
    sm.update_secret_version_stage(
        SecretId=arn, VersionStage="AWSCURRENT", MoveToVersionId=token, RemoveFromVersionId=current
    )
    keep = {token, current}
    for item in table.scan(ProjectionExpression="key_hash, version_id")["Items"]:
        if item["version_id"] not in keep:
            table.delete_item(Key={"key_hash": item["key_hash"]})
            logger.info(json.dumps({"revoked_version": item["version_id"]}))
