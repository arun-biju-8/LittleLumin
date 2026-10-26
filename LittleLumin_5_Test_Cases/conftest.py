import os
import pytest
import requests
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

@pytest.fixture(scope="session")
def base_url():
    return os.getenv("API_BASE_URL", "https://littlelumin.onrender.com").strip().rstrip("/")

@pytest.fixture(scope="session")
def http_session():
    session = requests.Session()
    session.headers.update({"User-Agent": "LittleLumin-Test-Suite/1.0", "Accept": "application/json"})
    yield session
    session.close()

@pytest.fixture
def driver():
    options = Options()
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1366,900")
    options.add_argument("--disable-gpu")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    browser = webdriver.Chrome(options=options)
    yield browser
    browser.quit()

@pytest.fixture(scope="session")
def ui_url():
    url = os.getenv("UI_URL", "").strip()
    if not url:
        pytest.skip("UI_URL is not set. Set it to the actual LittleLumin web frontend URL.")
    return url
