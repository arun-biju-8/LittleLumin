# backend/tests/test_health.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_root_endpoint():
    """Verify that root endpoint returns 200 with service metadata."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert "version" in data
    assert "service" in data

def test_health_endpoint():
    """Verify that health check endpoint returns 200 healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data

def test_cors_headers_on_allowed_origin():
    """Verify that CORS headers are properly returned for configured origins."""
    headers = {"Origin": "https://littlelumin-e7d26.web.app"}
    response = client.get("/health", headers=headers)
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == "https://littlelumin-e7d26.web.app"
    assert response.headers.get("access-control-allow-credentials") == "true"
