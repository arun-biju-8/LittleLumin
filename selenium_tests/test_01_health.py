import time
import pytest
import requests


@pytest.mark.api
def test_root_returns_online(base_url: str, http_session: requests.Session):
    """
    Test that the root endpoint (/) responds with HTTP 200 and status 'online'.
    """
    url = f"{base_url}/"
    print(f"\n[Running] test_root_returns_online: Sending GET to {url}")

    response = http_session.get(url, timeout=10)
    print(f"[Result] Status Code: {response.status_code}, Body: {response.text}")

    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}"
    data = response.json()
    assert data.get("status") == "online", f"Expected status 'online', got {data.get('status')}"


@pytest.mark.api
def test_health_returns_healthy(base_url: str, http_session: requests.Session):
    """
    Test that the health check endpoint (/health) responds with HTTP 200 and status 'healthy'.
    """
    url = f"{base_url}/health"
    print(f"\n[Running] test_health_returns_healthy: Sending GET to {url}")

    response = http_session.get(url, timeout=10)
    print(f"[Result] Status Code: {response.status_code}, Body: {response.text}")

    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}"
    data = response.json()
    assert data.get("status") == "healthy", f"Expected status 'healthy', got {data.get('status')}"


@pytest.mark.api
def test_root_response_time_under_3s(base_url: str, http_session: requests.Session):
    """
    Test that the root endpoint (/) responds within 3 seconds.
    """
    url = f"{base_url}/"
    print(f"\n[Running] test_root_response_time_under_3s: Measuring latency for {url}")

    start_time = time.time()
    response = http_session.get(url, timeout=10)
    elapsed_time = time.time() - start_time
    print(f"[Result] Status: {response.status_code}, Response time: {elapsed_time:.3f}s")

    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}"
    assert elapsed_time < 3.0, f"Response time {elapsed_time:.3f}s exceeded 3.0s threshold"


@pytest.mark.api
def test_health_response_time_under_3s(base_url: str, http_session: requests.Session):
    """
    Test that the health endpoint (/health) responds within 3 seconds.
    """
    url = f"{base_url}/health"
    print(f"\n[Running] test_health_response_time_under_3s: Measuring latency for {url}")

    start_time = time.time()
    response = http_session.get(url, timeout=10)
    elapsed_time = time.time() - start_time
    print(f"[Result] Status: {response.status_code}, Response time: {elapsed_time:.3f}s")

    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}"
    assert elapsed_time < 3.0, f"Response time {elapsed_time:.3f}s exceeded 3.0s threshold"


@pytest.mark.api
def test_root_has_correct_fields(base_url: str, http_session: requests.Session):
    """
    Test that the root endpoint (/) response includes all required schema fields:
    'status', 'service', and 'version'.
    """
    url = f"{base_url}/"
    print(f"\n[Running] test_root_has_correct_fields: Validating JSON schema from {url}")

    response = http_session.get(url, timeout=10)
    print(f"[Result] Status: {response.status_code}, Response Body: {response.text}")

    assert response.status_code == 200, f"Expected 200 OK, got {response.status_code}"
    data = response.json()

    for field in ["status", "service", "version"]:
        assert field in data, f"Missing required field '{field}' in response: {data}"

    assert data["service"] == "LittleLumin AI Service"
    assert data["version"] == "1.0.0"
