"""Demo client app: reads the current API key (cached) and calls the partner API.

If the cached key is rejected, it refreshes the key once and retries, so a rotation
never causes more than one extra call.
"""
import json
import logging
import os
import time

import boto3

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

CACHE_SECONDS = int(os.environ.get("CACHE_SECONDS", "300"))
_cache = {"value": None, "expires": 0.0}


def get_api_key(force_refresh: bool = False) -> str:
    now = time.time()
    if force_refresh or _cache["value"] is None or now >= _cache["expires"]:
        sm = boto3.client("secretsmanager")
        _cache["value"] = sm.get_secret_value(SecretId=os.environ["SECRET_ID"], VersionStage="AWSCURRENT")["SecretString"]
        _cache["expires"] = now + CACHE_SECONDS
    return _cache["value"]


def call_api(api_key: str) -> dict:
    response = boto3.client("lambda").invoke(
        FunctionName=os.environ["API_FUNCTION"],
        Payload=json.dumps({"api_key": api_key}).encode("utf-8"),
    )
    return json.loads(response["Payload"].read())


def lambda_handler(event, context):
    result = call_api(get_api_key())
    if result["statusCode"] == 403:
        logger.info(json.dumps({"msg": "cached key rejected, refreshing once"}))
        result = call_api(get_api_key(force_refresh=True))
    logger.info(json.dumps({"statusCode": result["statusCode"], "key_version": result.get("key_version")}))
    return result
