import os
import time
import pytest
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager


def pytest_configure(config):
    """Register custom pytest markers to avoid warnings."""
    config.addinivalue_line("markers", "api: Mark test as an API test.")
    config.addinivalue_line("markers", "ui: Mark test as a Selenium UI test.")
    config.addinivalue_line("markers", "slow: Mark test as a slow test.")


@pytest.fixture(scope="session")
def base_url() -> str:
    """
    Provide the base URL for backend API requests.
    Reads from the API_BASE_URL environment variable, defaulting to
    https://littlelumin-backend.onrender.com.
    """
    url = os.getenv("API_BASE_URL", "https://littlelumin-backend.onrender.com").strip().rstrip("/")
    print(f"\n[Fixture base_url] Using API Base URL: {url}")
    return url


@pytest.fixture(scope="session", autouse=True)
def warmup_backend():
    """Wake up the Render backend before any tests run."""
    base_url = os.getenv("API_BASE_URL", "https://littlelumin-backend.onrender.com").strip().rstrip("/")
    print("\n🔥 Warming up backend (Render cold start can take 30-60s)...")
    
    for attempt in range(5):
        try:
            r = requests.get(f"{base_url}/health", timeout=90)
            if r.status_code == 200:
                print(f"✅ Backend awake after {attempt + 1} attempt(s)")
                # Extra request to ensure it's fully warm
                try:
                    requests.get(f"{base_url}/", timeout=30)
                except Exception:
                    pass
                time.sleep(2)
                return
        except requests.exceptions.RequestException as e:
            print(f"⚠️ Warmup attempt {attempt + 1}/5 failed: {e}")
            time.sleep(3)
    
    pytest.exit("❌ Backend did not wake up after 5 attempts. Aborting tests.")


@pytest.fixture(scope="session")
def http_session():
    """
    Provide a shared requests.Session for API tests with retries, keep-alive,
    and standard headers.
    """
    session = requests.Session()
    retries = Retry(
        total=3,
        backoff_factor=0.5,
        status_forcelist=[502, 503, 504],
        raise_on_status=False
    )
    adapter = HTTPAdapter(max_retries=retries)
    session.mount("http://", adapter)
    session.mount("https://", adapter)

    session.headers.update({
        "User-Agent": "LittleLumin-Test-Suite/1.0",
        "Accept": "application/json",
    })
    print("\n[Fixture http_session] requests.Session initialized with retry adapter.")
    yield session
    session.close()
    print("\n[Fixture http_session] requests.Session closed.")


@pytest.fixture(scope="function")
def driver():
    """
    Provide a headless Chrome WebDriver managed via webdriver-manager.
    Configured for automated, sandbox-safe testing.
    """
    chrome_options = Options()
    chrome_options.add_argument("--headless=new")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")
    chrome_options.add_argument("--window-size=1920,1080")
    chrome_options.add_argument("--log-level=3")

    service = Service(ChromeDriverManager().install())
    chrome_driver = webdriver.Chrome(service=service, options=chrome_options)
    chrome_driver.implicitly_wait(10)
    print("\n[Fixture driver] Headless Chrome driver started.")
    yield chrome_driver
    chrome_driver.quit()
    print("\n[Fixture driver] Headless Chrome driver terminated.")
