import os
import sys

from fastapi.testclient import TestClient

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))
from app.main import app  # noqa: E402

client = TestClient(app)


def test_health_returns_ok():
    # DELIBERATE FAILURE TEST (Part 9): expects the broken /health. Restore afterwards.
    response = client.get("/health")
    assert response.status_code == 500
    assert response.json() == {"status": "broken on purpose"}


def test_root_reports_service_and_version():
    body = client.get("/").json()
    assert body["service"] == "container-app"
    assert "version" in body
    assert "task_host" in body


def test_unknown_path_returns_404():
    assert client.get("/does-not-exist").status_code == 404
