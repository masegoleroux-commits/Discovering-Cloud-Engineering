"""Unit tests run against moto's in-memory DynamoDB: no AWS calls, no Lambda invocations used."""
import importlib
import json
import os
import sys

import boto3
import pytest
from moto import mock_aws

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

TEST_TABLE_NAME = "notes-api-test-notes"


@pytest.fixture
def handler_module(monkeypatch):
    monkeypatch.setenv("AWS_DEFAULT_REGION", "us-east-1")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("TABLE_NAME", TEST_TABLE_NAME)
    with mock_aws():
        boto3.client("dynamodb").create_table(
            TableName=TEST_TABLE_NAME,
            KeySchema=[{"AttributeName": "note_id", "KeyType": "HASH"}],
            AttributeDefinitions=[{"AttributeName": "note_id", "AttributeType": "S"}],
            ProvisionedThroughput={"ReadCapacityUnits": 1, "WriteCapacityUnits": 1},
        )
        import handler

        importlib.reload(handler)
        yield handler


def make_event(route_key, body=None, note_id=None):
    return {
        "routeKey": route_key,
        "body": json.dumps(body) if body is not None else None,
        "pathParameters": {"note_id": note_id} if note_id else None,
    }


def test_create_then_get_round_trip(handler_module):
    created = handler_module.lambda_handler(make_event("POST /notes", {"title": "Hello"}), None)
    assert created["statusCode"] == 201
    note_id = json.loads(created["body"])["note_id"]

    fetched = handler_module.lambda_handler(make_event("GET /notes/{note_id}", note_id=note_id), None)
    assert fetched["statusCode"] == 200
    assert json.loads(fetched["body"])["title"] == "Hello"


def test_list_returns_created_notes(handler_module):
    handler_module.lambda_handler(make_event("POST /notes", {"title": "One"}), None)
    handler_module.lambda_handler(make_event("POST /notes", {"title": "Two"}), None)
    listed = handler_module.lambda_handler(make_event("GET /notes"), None)
    assert json.loads(listed["body"])["count"] == 2


def test_missing_title_returns_400(handler_module):
    response = handler_module.lambda_handler(make_event("POST /notes", {"content": "x"}), None)
    assert response["statusCode"] == 400


def test_title_too_long_returns_400(handler_module):
    response = handler_module.lambda_handler(make_event("POST /notes", {"title": "x" * 101}), None)
    assert response["statusCode"] == 400


def test_invalid_json_returns_400(handler_module):
    event = {"routeKey": "POST /notes", "body": "{not json", "pathParameters": None}
    assert handler_module.lambda_handler(event, None)["statusCode"] == 400


def test_non_object_json_returns_400(handler_module):
    event = {"routeKey": "POST /notes", "body": "[1, 2]", "pathParameters": None}
    assert handler_module.lambda_handler(event, None)["statusCode"] == 400


def test_unknown_note_returns_404(handler_module):
    response = handler_module.lambda_handler(make_event("GET /notes/{note_id}", note_id="missing"), None)
    assert response["statusCode"] == 404


def test_delete_removes_note(handler_module):
    created = handler_module.lambda_handler(make_event("POST /notes", {"title": "Temp"}), None)
    note_id = json.loads(created["body"])["note_id"]
    deleted = handler_module.lambda_handler(make_event("DELETE /notes/{note_id}", note_id=note_id), None)
    assert deleted["statusCode"] == 204
    after = handler_module.lambda_handler(make_event("GET /notes/{note_id}", note_id=note_id), None)
    assert after["statusCode"] == 404


def test_unknown_route_returns_404(handler_module):
    assert handler_module.lambda_handler(make_event("PATCH /notes"), None)["statusCode"] == 404
