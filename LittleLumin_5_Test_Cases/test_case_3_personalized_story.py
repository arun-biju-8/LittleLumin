import requests

BASE_URL = "https://littlelumin.onrender.com"

def test_case_3_personalized_story():
    url = f"{BASE_URL}/api/ai/generate-story"

    payload = {
        "child_name": "Luna",
        "topic_or_moral": "Sharing and Kindness",
        "age_years": 4
    }

    print("\nTEST CASE 3: PERSONALIZED STORY GENERATION")
    print("Request URL:", url)
    print("Request Data:", payload)

    response = requests.post(
        url,
        json=payload,
        timeout=90
    )

    print("\nHTTP Status:", response.status_code)
    print("Response Headers:", dict(response.headers))
    print("Response Length:", len(response.content))
    print("Response Body:", repr(response.text[:2000]))

    if not response.content:
        print("\nDIAGNOSTIC: The response body is empty.")
    else:
        try:
            data = response.json()
            print("Parsed JSON:", data)
        except requests.exceptions.JSONDecodeError:
            print("DIAGNOSTIC: Response is not valid JSON.")

    print("\nDiagnostic completed.")