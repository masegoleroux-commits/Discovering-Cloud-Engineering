"""Notes API Lambda handler: one function, four routes, routed on event['routeKey']."""
import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

MAX_TITLE_LENGTH = 100
MAX_CONTENT_LENGTH = 2000
LIST_PAGE_LIMIT = 50

_table = None


def get_table():
    """Create the DynamoDB Table object lazily so tests can mock AWS first."""
    global _table
    if _table is None:
        _table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
    return _table


def build_response(status_code, body=None):
    response = {"statusCode": status_code, "headers": {"Content-Type": "application/json"}}
    if body is not None:
        response["body"] = json.dumps(body)
    return response


def log_event(level, message, **fields):
    LOGGER.log(level, json.dumps({"message": message, **fields}))


def validate_note(payload):
    """Return an error message, or None if the payload is valid."""
    if not isinstance(payload, dict):
        return "body must be a JSON object"
    title = payload.get("title")
    content = payload.get("content", "")
    if not isinstance(title, str) or not title.strip():
        return "title is required"
    if len(title) > MAX_TITLE_LENGTH:
        return f"title must be {MAX_TITLE_LENGTH} characters or fewer"
    if not isinstance(content, str) or len(content) > MAX_CONTENT_LENGTH:
        return f"content must be a string of {MAX_CONTENT_LENGTH} characters or fewer"
    return None


def create_note(event):
    try:
        payload = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return build_response(400, {"error": "body must be valid JSON"})

    error = validate_note(payload)
    if error:
        return build_response(400, {"error": error})

    note = {
        "note_id": str(uuid.uuid4()),
        "title": payload["title"].strip(),
        "content": payload.get("content", ""),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    get_table().put_item(Item=note)
    log_event(logging.INFO, "note_created", note_id=note["note_id"])
    return build_response(201, note)


def get_note(note_id):
    item = get_table().get_item(Key={"note_id": note_id}).get("Item")
    if item is None:
        return build_response(404, {"error": "note not found"})
    return build_response(200, item)


def list_notes():
    result = get_table().scan(Limit=LIST_PAGE_LIMIT)
    return build_response(200, {"items": result.get("Items", []), "count": result.get("Count", 0)})


def delete_note(note_id):
    get_table().delete_item(Key={"note_id": note_id})
    log_event(logging.INFO, "note_deleted", note_id=note_id)
    return build_response(204)


def lambda_handler(event, context):
    route_key = event.get("routeKey", "")
    path_params = event.get("pathParameters") or {}
    request_id = getattr(context, "aws_request_id", "local")
    log_event(logging.INFO, "request_received", route_key=route_key, request_id=request_id)

    try:
        if route_key == "POST /notes":
            return create_note(event)
        if route_key == "GET /notes":
            return list_notes()
        if route_key == "GET /notes/{note_id}":
            return get_note(path_params["note_id"])
        if route_key == "DELETE /notes/{note_id}":
            return delete_note(path_params["note_id"])
        return build_response(404, {"error": "route not found"})
    except Exception as exc:  # last-resort guard: details go to logs, not to the caller
        log_event(logging.ERROR, "unhandled_error", error=str(exc), request_id=request_id)
        return build_response(500, {"error": "internal error", "request_id": request_id})
