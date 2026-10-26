import requests

BASE_URL = "https://littlelumin.onrender.com"

def test_case_1_root_endpoint_availability():
    url = f"{BASE_URL}/"

    print("\nTEST CASE 1: ROOT ENDPOINT AVAILABILITY")
    print("URL:", url)

    response = requests.get(url, timeout=90)

    print("HTTP Status:", response.status_code)
    print("Content-Type:", response.headers.get("Content-Type"))
    print("Response Preview:", response.text[:300])

    assert response.status_code == 200, (
        f"Expected HTTP 200, got {response.status_code}"
    )

    assert "text/html" in response.headers.get("Content-Type", ""), (
        "Expected an HTML response from the root endpoint"
    )

    assert "<html" in response.text.lower(), (
        "HTML document was not found in the response"
    )

    print("TEST RESULT: PASS")
    print("Root endpoint is accessible and serves HTML.")