import requests

BASE_URL = "https://littlelumin.onrender.com"


def test_case_5_invalid_page():
    print("\nTEST CASE 5: INVALID PAGE HANDLING")

    invalid_url = f"{BASE_URL}/this-page-should-not-exist-12345"

    print("Request URL:", invalid_url)

    response = requests.get(
        invalid_url,
        timeout=30,
        allow_redirects=False
    )

    print("HTTP Status:", response.status_code)
    print("Response Length:", len(response.content))

    # A missing page should return HTTP 404.
    assert response.status_code == 404, (
        f"Expected HTTP 404, received HTTP {response.status_code}"
    )

    print("TEST RESULT: PASS")
    print("The server correctly returned HTTP 404 for an invalid URL.")