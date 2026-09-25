import pytest
import requests


@pytest.mark.api
def test_get_on_post_endpoint_returns_405(base_url: str, http_session: requests.Session):
    """
    Test that sending an HTTP GET request to a POST-only endpoint
    (/api/ai/generate-activity) returns HTTP 405 Method Not Allowed.
    """
    url = f"{base_url}/api/ai/generate-activity"
    print(f"\n[Running] test_get_on_post_endpoint_returns_405: GET {url}")

    response = http_session.get(url, timeout=10)
    print(f"[Result] Status Code: {response.status_code}")

    assert response.status_code == 405, f"Expected 405 Method Not Allowed, got {response.status_code}"


@pytest.mark.api
def test_invalid_json_returns_400_or_422(base_url: str, http_session: requests.Session):
    """
    Test that sending malformed JSON to /api/ai/generate-activity
    returns HTTP 400 Bad Request or HTTP 422 Unprocessable Entity.
    """
    url = f"{base_url}/api/ai/generate-activity"
    malformed_data = '{"skill_domain": "Cognitive", "difficulty": '
    headers = {"Content-Type": "application/json"}
    print(f"\n[Running] test_invalid_json_returns_400_or_422: POST {url} with malformed JSON string")

    response = http_session.post(url, data=malformed_data, headers=headers, timeout=10)
    print(f"[Result] Status Code: {response.status_code}, Body: {response.text[:200]}")

    assert response.status_code in [400, 422], (
        f"Expected HTTP 400 or 422 for malformed JSON, got {response.status_code}"
    )


@pytest.mark.api
def test_unknown_endpoint_returns_404(base_url: str, http_session: requests.Session):
    """
    Test that requesting an undefined endpoint returns HTTP 404 Not Found.
    """
    url = f"{base_url}/nonexistent-api-path-404"
    print(f"\n[Running] test_unknown_endpoint_returns_404: GET {url}")

    response = http_session.get(url, timeout=10)
    print(f"[Result] Status Code: {response.status_code}")

    assert response.status_code == 404, f"Expected 404 Not Found, got {response.status_code}"


@pytest.mark.api
def test_empty_body_returns_422(base_url: str, http_session: requests.Session):
    """
    Test that sending an empty POST body to an endpoint requiring a JSON payload
    returns HTTP 422 Unprocessable Entity.
    """
    url = f"{base_url}/api/ai/generate-activity"
    headers = {"Content-Type": "application/json"}
    print(f"\n[Running] test_empty_body_returns_422: POST {url} with empty payload")

    response = http_session.post(url, data="", headers=headers, timeout=10)
    print(f"[Result] Status Code: {response.status_code}, Body: {response.text[:200]}")

    assert response.status_code == 422, f"Expected 422 for empty body, got {response.status_code}"


@pytest.mark.api
def test_wrong_content_type_returns_400_or_415(base_url: str, http_session: requests.Session):
    """
    Test that sending an unsupported content-type (text/plain) returns
    HTTP 400, 415 Unsupported Media Type, or 422 Unprocessable Entity.
    """
    url = f"{base_url}/api/ai/generate-activity"
    headers = {"Content-Type": "text/plain"}
    print(f"\n[Running] test_wrong_content_type_returns_400_or_415: POST {url} with text/plain header")

    response = http_session.post(url, data="skill_domain=Cognitive", headers=headers, timeout=10)
    print(f"[Result] Status Code: {response.status_code}, Body: {response.text[:200]}")

    assert response.status_code in [400, 415, 422], (
        f"Expected HTTP 400, 415, or 422 for incorrect content-type, got {response.status_code}"
    )


@pytest.mark.api
def test_sql_injection_in_child_name_returns_success_or_400(base_url: str, http_session: requests.Session):
    """
    Test that passing SQL injection syntax in string inputs is handled safely:
    either rejected by WAF/input validation (HTTP 400/403/422) or treated as a safe
    literal string (HTTP 200/500), without exposing database internal errors.
    """
    url = f"{base_url}/api/ai/generate-activity"
    payload = {
        "skill_domain": "Cognitive",
        "difficulty": "Medium",
        "age_years": 4,
        "child_name": "Robert'); DROP TABLE Users;--"
    }
    print(f"\n[Running] test_sql_injection_in_child_name_returns_success_or_400: POST {url} with SQL injection payload")

    response = http_session.post(url, json=payload, timeout=20)
    print(f"[Result] Status Code: {response.status_code}, Body: {response.text[:200]}")

    # Should be safely handled (blocked by WAF 403, rejected 400/422, or accepted as safe literal 200/500)
    assert response.status_code in [200, 400, 403, 422, 500], (
        f"Unexpected status code for SQL injection test: {response.status_code}"
    )
    # Ensure no raw database crash message is leaked
    lowered_body = response.text.lower()
    for sql_leak in ["syntax error at or near", "sql syntax", "sqlite3.operationalerror", "psycopg2"]:
        assert sql_leak not in lowered_body, f"SQL error leaked in response: {response.text}"
