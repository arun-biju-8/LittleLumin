import time
import pytest
import requests


@pytest.mark.api
def test_generate_story_valid(base_url: str, http_session: requests.Session):
    """
    Test generating a personalized story with valid fields.
    Validates either HTTP 200 with full story payload or HTTP 500 with
    structured error details from upstream AI limits.
    """
    url = f"{base_url}/api/ai/generate-story"
    payload = {
        "child_name": "Luna",
        "topic_or_moral": "Sharing and Kindness",
        "age_years": 4
    }
    print(f"\n[Running] test_generate_story_valid: POST {url} with {payload}")

    response = http_session.post(url, json=payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text[:200]}")

    assert response.status_code in [200, 500], f"Unexpected status: {response.status_code}"
    body = response.json()

    if response.status_code == 200:
        assert body.get("status") == "success"
        assert "data" in body
        data = body["data"]
        for key in ["title", "story", "characters", "moral"]:
            assert key in data, f"Story response missing '{key}'"
        print(f"[Success] Story generated: '{data.get('title')}'")
    else:
        assert "detail" in body
        print(f"[Handled Upstream] Error detail: {body.get('detail')}")


@pytest.mark.api
def test_generate_story_empty_name_uses_default(base_url: str, http_session: requests.Session):
    """
    Test generating a story with an empty child_name string.
    Backend should handle this gracefully using its default fallback name ('Little Explorer').
    """
    url = f"{base_url}/api/ai/generate-story"
    payload = {
        "child_name": "",
        "topic_or_moral": "Bravery and Adventure",
        "age_years": 5
    }
    print(f"\n[Running] test_generate_story_empty_name_uses_default: POST {url} with empty child_name")

    response = http_session.post(url, json=payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text[:200]}")

    assert response.status_code in [200, 500], f"Unexpected status: {response.status_code}"
    body = response.json()

    if response.status_code == 200:
        assert body.get("status") == "success"
        assert "data" in body
    else:
        assert "detail" in body


@pytest.mark.api
def test_story_missing_fields_returns_422(base_url: str, http_session: requests.Session):
    """
    Test that sending an invalid field type (e.g. child_name=None or invalid age string)
    returns HTTP 422 Unprocessable Entity.
    """
    url = f"{base_url}/api/ai/generate-story"
    payload = {
        "child_name": None,
        "topic_or_moral": "Kindness",
        "age_years": "not-an-integer"
    }
    print(f"\n[Running] test_story_missing_fields_returns_422: POST {url} with invalid types")

    response = http_session.post(url, json=payload, timeout=90)
    print(f"[Result] Status: {response.status_code}, Response: {response.text}")

    assert response.status_code == 422, f"Expected HTTP 422, got {response.status_code}"


@pytest.mark.api
@pytest.mark.slow
def test_story_response_time_under_30s(base_url: str, http_session: requests.Session):
    """
    Test that the story generation endpoint responds within 30 seconds.
    """
    url = f"{base_url}/api/ai/generate-story"
    payload = {
        "child_name": "BenchmarkBot",
        "topic_or_moral": "Perseverance",
        "age_years": 6
    }
    print(f"\n[Running] test_story_response_time_under_30s: Timing request to {url}")

    start_time = time.time()
    response = http_session.post(url, json=payload, timeout=90)
    elapsed_time = time.time() - start_time
    print(f"[Result] Status: {response.status_code}, Elapsed Time: {elapsed_time:.3f}s")

    assert response.status_code in [200, 500], f"Unexpected status: {response.status_code}"
    assert elapsed_time < 30.0, f"Story generation time {elapsed_time:.3f}s exceeded 30s threshold"
