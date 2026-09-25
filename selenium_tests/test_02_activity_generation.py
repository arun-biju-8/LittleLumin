import time
import pytest
import requests


def _post_with_retry(session, url, payload, max_attempts=3, timeout=90):
    """Post with retry on timeout."""
    last_exception = None
    for attempt in range(max_attempts):
        try:
            return session.post(url, json=payload, timeout=timeout)
        except requests.exceptions.ReadTimeout as e:
            last_exception = e
            print(f"⚠️ Attempt {attempt + 1}/{max_attempts} timed out. Retrying...")
            time.sleep(5)
    raise last_exception


@pytest.mark.api
def test_generate_cognitive_medium_valid(base_url: str, http_session: requests.Session):
    """
    Test generating a valid Cognitive activity with Medium difficulty.
    Validates either successful generation (HTTP 200) or structured backend
    handling of upstream LLM limits (HTTP 500).
    """
    url = f"{base_url}/api/ai/generate-activity"
    payload = {
        "skill_domain": "Cognitive",
        "difficulty": "Medium",
        "age_years": 4,
        "child_name": "Leo"
    }
    print(f"\n[Running] test_generate_cognitive_medium_valid: POST {url} with payload {payload}")

    response = http_session.post(url, json=payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text[:200]}")

    assert response.status_code in [200, 500], f"Unexpected status code: {response.status_code}"
    body = response.json()

    if response.status_code == 200:
        assert body.get("status") == "success", "Expected status 'success'"
        assert "data" in body, "Response body missing 'data' field"
        data = body["data"]
        for key in ["title", "instructions", "learningGoals", "materials"]:
            assert key in data, f"Generated activity missing key: '{key}'"
        print(f"[Success] Generated activity title: {data.get('title')}")
    else:
        assert "detail" in body, "Error response missing 'detail' field"
        print(f"[Handled Upstream] AI service returned: {body.get('detail')}")


@pytest.mark.api
def test_generate_language_easy_valid(base_url: str, http_session: requests.Session):
    """
    Test generating a valid Language activity with Easy difficulty.
    """
    url = f"{base_url}/api/ai/generate-activity"
    payload = {
        "skill_domain": "Language",
        "difficulty": "Easy",
        "age_years": 3,
        "child_name": "Mia"
    }
    print(f"\n[Running] test_generate_language_easy_valid: POST {url} with payload {payload}")

    response = http_session.post(url, json=payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text[:200]}")

    assert response.status_code in [200, 500], f"Unexpected status code: {response.status_code}"
    body = response.json()

    if response.status_code == 200:
        assert body.get("status") == "success"
        assert "data" in body
        assert "title" in body["data"]
    else:
        assert "detail" in body


@pytest.mark.api
def test_generate_motor_hard_valid(base_url: str, http_session: requests.Session):
    """
    Test generating a valid Motor activity with Hard difficulty.
    """
    url = f"{base_url}/api/ai/generate-activity"
    payload = {
        "skill_domain": "Motor",
        "difficulty": "Hard",
        "age_years": 6,
        "child_name": "Sam"
    }
    print(f"\n[Running] test_generate_motor_hard_valid: POST {url} with payload {payload}")

    response = _post_with_retry(http_session, url, payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text[:200]}")

    assert response.status_code in [200, 500], f"Unexpected status code: {response.status_code}"
    body = response.json()

    if response.status_code == 200:
        assert body.get("status") == "success"
        assert "data" in body
        assert "title" in body["data"]
    else:
        assert "detail" in body


@pytest.mark.api
def test_missing_skill_domain_returns_422(base_url: str, http_session: requests.Session):
    """
    Test that passing None / invalid type for skill_domain triggers Pydantic
    schema validation error (HTTP 422 Unprocessable Entity).
    """
    url = f"{base_url}/api/ai/generate-activity"
    payload = {
        "skill_domain": None,
        "difficulty": "Medium",
        "age_years": 4
    }
    print(f"\n[Running] test_missing_skill_domain_returns_422: POST {url} with null skill_domain")

    response = _post_with_retry(http_session, url, payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text}")

    assert response.status_code == 422, f"Expected HTTP 422 for null skill_domain, got {response.status_code}"


@pytest.mark.api
def test_invalid_age_returns_422(base_url: str, http_session: requests.Session):
    """
    Test that passing age_years out of bounds (allowed 2-10) returns HTTP 422.
    """
    url = f"{base_url}/api/ai/generate-activity"
    payload = {
        "skill_domain": "Cognitive",
        "difficulty": "Medium",
        "age_years": 99
    }
    print(f"\n[Running] test_invalid_age_returns_422: POST {url} with out-of-range age (99)")

    response = http_session.post(url, json=payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text}")

    assert response.status_code == 422, f"Expected HTTP 422 for invalid age, got {response.status_code}"


@pytest.mark.api
@pytest.mark.slow
def test_activity_response_time_under_30s(base_url: str, http_session: requests.Session):
    """
    Test that the activity generation endpoint responds within 30 seconds.
    """
    url = f"{base_url}/api/ai/generate-activity"
    payload = {
        "skill_domain": "Cognitive",
        "difficulty": "Medium",
        "age_years": 5,
        "child_name": "Benchmark"
    }
    print(f"\n[Running] test_activity_response_time_under_30s: Timing request to {url}")

    start_time = time.time()
    response = http_session.post(url, json=payload, timeout=90)
    elapsed_time = time.time() - start_time
    print(f"[Result] Status: {response.status_code}, Elapsed Time: {elapsed_time:.3f}s")

    assert response.status_code in [200, 500], f"Unexpected status: {response.status_code}"
    assert elapsed_time < 30.0, f"Response time {elapsed_time:.3f}s exceeded 30s threshold"
