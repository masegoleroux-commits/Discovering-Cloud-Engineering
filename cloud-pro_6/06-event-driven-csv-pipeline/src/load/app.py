"""Load a validated orders CSV into DynamoDB."""
import csv
import io
import json
import logging
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel("INFO")

_s3 = None
_table = None


def get_clients():
    global _s3, _table
    if _s3 is None:
        _s3 = boto3.client("s3")
        _table = boto3.resource("dynamodb").Table(os.environ["ORDERS_TABLE_NAME"])
    return _s3, _table


def to_item(row, source_key, loaded_at):
    return {
        "order_id": row["order_id"].strip(),
        "customer_email": row["customer_email"].strip().lower(),
        "amount": Decimal(row["amount"]),  # DynamoDB rejects Python floats
        "currency": row["currency"],
        "order_date": row["order_date"],
        "source_key": source_key,
        "loaded_at": loaded_at,
    }


def lambda_handler(event, context):
    s3, table = get_clients()
    bucket, key = event["bucket"], event["key"]
    text = s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8-sig")
    loaded_at = datetime.now(timezone.utc).isoformat()

    loaded_count = 0
    # overwrite_by_pkeys makes re-uploads replace rows instead of duplicating them
    with table.batch_writer(overwrite_by_pkeys=["order_id"]) as batch:
        for row in csv.DictReader(io.StringIO(text)):
            batch.put_item(Item=to_item(row, key, loaded_at))
            loaded_count += 1

    LOGGER.info(json.dumps({"message": "file_loaded", "key": key, "loaded_count": loaded_count}))
    return {"loaded_count": loaded_count}
