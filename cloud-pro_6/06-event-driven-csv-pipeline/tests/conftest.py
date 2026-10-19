import os

import pytest


@pytest.fixture(autouse=True)
def fake_aws_credentials(monkeypatch):
    """Make sure tests can never reach a real AWS account."""
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")


DATA_DIR = os.path.join(os.path.dirname(__file__), "data")


def read_data(name):
    with open(os.path.join(DATA_DIR, name), encoding="utf-8") as handle:
        return handle.read()
