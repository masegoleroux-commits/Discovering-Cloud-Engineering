import importlib.util
import os
from decimal import Decimal

import boto3
from moto import mock_aws

from conftest import read_data

SRC = os.path.join(os.path.dirname(__file__), "..", "src", "load", "app.py")
TABLE = "csv-pipeline-test-orders"


def load_module():
    spec = importlib.util.spec_from_file_location("load_app", SRC)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def setup_aws():
    s3 = boto3.client("s3")
    s3.create_bucket(Bucket="test-bucket")
    s3.put_object(Bucket="test-bucket", Key="incoming/valid.csv", Body=read_data("valid_orders.csv"))
    boto3.client("dynamodb").create_table(
        TableName=TABLE,
        KeySchema=[{"AttributeName": "order_id", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "order_id", "AttributeType": "S"}],
        ProvisionedThroughput={"ReadCapacityUnits": 1, "WriteCapacityUnits": 1},
    )


def test_load_writes_every_row(monkeypatch):
    monkeypatch.setenv("ORDERS_TABLE_NAME", TABLE)
    with mock_aws():
        setup_aws()
        load = load_module()
        result = load.lambda_handler({"bucket": "test-bucket", "key": "incoming/valid.csv"}, None)
        assert result == {"loaded_count": 3}

        item = boto3.resource("dynamodb").Table(TABLE).get_item(Key={"order_id": "ORD-1001"})["Item"]
        assert item["amount"] == Decimal("249.99")
        assert item["source_key"] == "incoming/valid.csv"


def test_reloading_same_file_does_not_duplicate(monkeypatch):
    monkeypatch.setenv("ORDERS_TABLE_NAME", TABLE)
    with mock_aws():
        setup_aws()
        load = load_module()
        event = {"bucket": "test-bucket", "key": "incoming/valid.csv"}
        load.lambda_handler(event, None)
        load.lambda_handler(event, None)
        assert boto3.resource("dynamodb").Table(TABLE).scan()["Count"] == 3
