"""Validate an uploaded orders CSV. Raises ValidationError so Step Functions can route it."""
import csv
import io
import json
import logging
import os
from datetime import date
from decimal import Decimal, InvalidOperation

import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel("INFO")

EXPECTED_COLUMNS = ["order_id", "customer_email", "amount", "currency", "order_date"]
ALLOWED_CURRENCIES = {"ZAR", "USD", "EUR", "GBP"}
MAX_FILE_BYTES = int(os.environ.get("MAX_FILE_BYTES", "1048576"))
MAX_ROWS = int(os.environ.get("MAX_ROWS", "1000"))
MAX_REPORTED_ERRORS = 5

_s3 = None


class ValidationError(Exception):
    """The file breaks the contract. Step Functions sees the class name as the error name."""


def get_s3():
    global _s3
    if _s3 is None:
        _s3 = boto3.client("s3")
    return _s3


def validate_row(row):
    """Return a list of problems with one row (an empty list means the row is valid)."""
    problems = []
    if not (row.get("order_id") or "").strip():
        problems.append("order_id is empty")
    if "@" not in (row.get("customer_email") or ""):
        problems.append("customer_email is not an email address")
    try:
        amount = Decimal(row.get("amount") or "")
        if not amount.is_finite() or amount <= 0:
            problems.append("amount must be greater than 0")
    except InvalidOperation:
        problems.append("amount is not a number")
    if row.get("currency") not in ALLOWED_CURRENCIES:
        problems.append(f"currency must be one of {sorted(ALLOWED_CURRENCIES)}")
    try:
        date.fromisoformat(row.get("order_date") or "")
    except ValueError:
        problems.append("order_date is not YYYY-MM-DD")
    return problems


def validate_csv_text(text):
    """Validate a whole file. Returns the row count, or raises ValidationError."""
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames != EXPECTED_COLUMNS:
        raise ValidationError(f"header must be {','.join(EXPECTED_COLUMNS)}, got {reader.fieldnames}")

    errors, seen_ids, row_count = [], set(), 0
    for line_number, row in enumerate(reader, start=2):
        row_count += 1
        if row_count > MAX_ROWS:
            raise ValidationError(f"file has more than {MAX_ROWS} rows")
        for problem in validate_row(row):
            errors.append(f"line {line_number}: {problem}")
        order_id = (row.get("order_id") or "").strip()
        if order_id and order_id in seen_ids:
            errors.append(f"line {line_number}: duplicate order_id {order_id}")
        seen_ids.add(order_id)

    if row_count == 0:
        raise ValidationError("file has no data rows")
    if errors:
        raise ValidationError("; ".join(errors[:MAX_REPORTED_ERRORS]) + f" ({len(errors)} problems total)")
    return row_count


def lambda_handler(event, context):
    bucket, key = event["bucket"], event["key"]
    size = get_s3().head_object(Bucket=bucket, Key=key)["ContentLength"]
    if size > MAX_FILE_BYTES:
        raise ValidationError(f"file is {size} bytes; limit is {MAX_FILE_BYTES}")

    try:
        text = get_s3().get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ValidationError("file is not UTF-8 text") from exc

    row_count = validate_csv_text(text)
    LOGGER.info(json.dumps({"message": "file_valid", "key": key, "row_count": row_count}))
    return {"row_count": row_count}
