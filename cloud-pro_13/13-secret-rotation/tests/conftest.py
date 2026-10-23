import importlib.util
import os
import sys
from pathlib import Path

import boto3
import pytest
from moto import mock_aws

SRC = Path(__file__).resolve().parent.parent / "src"


def load(name):
    """Import src/<name>/app.py as its own module (all three files are called app.py)."""
    spec = importlib.util.spec_from_file_location(f"{name}_app", SRC / name / "app.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[f"{name}_app"] = module
    spec.loader.exec_module(module)
    return module


@pytest.fixture(autouse=True)
def aws_env(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-north-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("REGISTRY_TABLE", "registry")
    monkeypatch.setenv("API_FUNCTION", "api")
    monkeypatch.setenv("SECRET_ID", "partner-api-key")


@pytest.fixture
def aws():
    with mock_aws():
        ddb = boto3.resource("dynamodb", region_name="eu-north-1")
        table = ddb.create_table(
            TableName="registry",
            KeySchema=[{"AttributeName": "key_hash", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "key_hash", "AttributeType": "S"}],
            BillingMode="PAY_PER_REQUEST",
        )
        sm = boto3.client("secretsmanager", region_name="eu-north-1")
        yield sm, table
