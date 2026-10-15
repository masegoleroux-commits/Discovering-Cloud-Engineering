import importlib.util
import os

import boto3
import pytest
from moto import mock_aws

from conftest import read_data

SRC = os.path.join(os.path.dirname(__file__), "..", "src", "validate", "app.py")


def load_module():
    spec = importlib.util.spec_from_file_location("validate_app", SRC)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validate = load_module()


def test_valid_file_returns_row_count():
    assert validate.validate_csv_text(read_data("valid_orders.csv")) == 3


def test_invalid_file_lists_reasons():
    with pytest.raises(validate.ValidationError) as error:
        validate.validate_csv_text(read_data("invalid_orders.csv"))
    message = str(error.value)
    assert "customer_email" in message
    assert "duplicate order_id ORD-2002" in message
    assert "(5 problems total)" in message


def test_wrong_header_rejected():
    with pytest.raises(validate.ValidationError, match="header"):
        validate.validate_csv_text("id,email\n1,a@b.com\n")


def test_empty_file_rejected():
    with pytest.raises(validate.ValidationError, match="no data rows"):
        validate.validate_csv_text("order_id,customer_email,amount,currency,order_date\n")


def test_too_many_rows_rejected():
    header = "order_id,customer_email,amount,currency,order_date\n"
    rows = "".join(f"ORD-{i},a@b.com,1,ZAR,2026-10-15\n" for i in range(validate.MAX_ROWS + 1))
    with pytest.raises(validate.ValidationError, match="more than"):
        validate.validate_csv_text(header + rows)


@pytest.mark.parametrize(
    "field,value",
    [("amount", "abc"), ("amount", "0"), ("amount", "NaN"), ("currency", "JPY"), ("order_date", "2026-13-01")],
)
def test_single_field_problems(field, value):
    row = {"order_id": "X", "customer_email": "a@b.com", "amount": "1", "currency": "ZAR", "order_date": "2026-10-15"}
    row[field] = value
    assert validate.validate_row(row)


def test_handler_reads_from_s3():
    with mock_aws():
        s3 = boto3.client("s3")
        s3.create_bucket(Bucket="test-bucket")
        s3.put_object(Bucket="test-bucket", Key="incoming/valid.csv", Body=read_data("valid_orders.csv"))
        validate._s3 = None
        assert validate.lambda_handler({"bucket": "test-bucket", "key": "incoming/valid.csv"}, None) == {"row_count": 3}
        validate._s3 = None
