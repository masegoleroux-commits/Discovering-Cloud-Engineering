"""Test cases for the demo API and client app (TC-13-U09 to U13)."""
import hashlib
import io
import json

from conftest import load

api = load("api")
client = load("client")


def register(table, key, version="v1"):
    table.put_item(Item={"key_hash": hashlib.sha256(key.encode()).hexdigest(), "version_id": version})


def test_api_accepts_registered_key(aws):
    """TC-13-U09: a registered key gets 200 and the key's version."""
    _, table = aws
    register(table, "good-key")
    result = api.lambda_handler({"api_key": "good-key"}, None)
    assert result["statusCode"] == 200 and result["key_version"] == "v1"


def test_api_rejects_unknown_key(aws):
    """TC-13-U10: an unknown key gets 403."""
    _, table = aws
    register(table, "good-key")
    assert api.lambda_handler({"api_key": "stolen-or-old-key"}, None)["statusCode"] == 403


def test_api_rejects_missing_key(aws):
    """TC-13-U11: a request with no key gets 400."""
    assert api.lambda_handler({}, None)["statusCode"] == 400


class FakeLambda:
    def __init__(self, handler):
        self.handler = handler

    def invoke(self, FunctionName, Payload):
        return {"Payload": io.BytesIO(json.dumps(self.handler(json.loads(Payload), None)).encode())}


def test_client_caches_the_key(aws, monkeypatch):
    """TC-13-U12: the client reads the secret once, then uses its cache."""
    sm, table = aws
    sm.create_secret(Name="partner-api-key", SecretString="good-key")
    register(table, "good-key")
    calls = {"n": 0}
    real = client.boto3.client

    def counting_client(service, *a, **kw):
        if service == "lambda":
            return FakeLambda(api.lambda_handler)
        c = real(service, *a, **kw)
        original = c.get_secret_value

        def wrapped(**kwargs):
            calls["n"] += 1
            return original(**kwargs)

        c.get_secret_value = wrapped
        return c

    monkeypatch.setattr(client.boto3, "client", counting_client)
    client._cache.update(value=None, expires=0.0)
    assert client.lambda_handler({}, None)["statusCode"] == 200
    assert client.lambda_handler({}, None)["statusCode"] == 200
    assert calls["n"] == 1


def test_client_refreshes_once_when_its_cached_key_is_revoked(aws, monkeypatch):
    """TC-13-U13: if the cached key is rejected, the client re-reads the secret and succeeds."""
    sm, table = aws
    sm.create_secret(Name="partner-api-key", SecretString="new-key")
    register(table, "new-key", "v3")
    real = client.boto3.client
    monkeypatch.setattr(client.boto3, "client", lambda s, *a, **kw: FakeLambda(api.lambda_handler) if s == "lambda" else real(s, *a, **kw))
    client._cache.update(value="revoked-key", expires=9e18)  # a stale key still in the cache
    result = client.lambda_handler({}, None)
    assert result["statusCode"] == 200 and result["key_version"] == "v3"
