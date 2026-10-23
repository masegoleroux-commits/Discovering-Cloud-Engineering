"""Demo partner API: accepts a request only if its API key is in the key registry.

The registry holds SHA-256 hashes, so a leaked table never reveals a usable key.
"""
import hashlib
import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def _table():
    return boto3.resource("dynamodb").Table(os.environ["REGISTRY_TABLE"])


def lambda_handler(event, context):
    api_key = (event or {}).get("api_key")
    if not api_key:
        return {"statusCode": 400, "body": "missing api_key"}
    digest = hashlib.sha256(api_key.encode("utf-8")).hexdigest()
    item = _table().get_item(Key={"key_hash": digest}).get("Item")
    if not item:
        logger.info(json.dumps({"result": "rejected"}))
        return {"statusCode": 403, "body": "invalid api_key"}
    logger.info(json.dumps({"result": "accepted", "version_id": item["version_id"]}))
    return {"statusCode": 200, "body": "ok", "key_version": item["version_id"]}
