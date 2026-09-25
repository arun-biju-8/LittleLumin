# LittleLumin Backend & UI Test Suite

Automated end-to-end and integration test suite for the LittleLumin FastAPI backend and Web UI using **pytest 9.1.1**, **requests 2.34.2**, and **selenium 4.49.0**.

---

## 📋 Features

- **API Health Tests (`test_01_health.py`)**: Validates `/` root, `/health` ping, latencies (<3s), and schema integrity.
- **AI Activity Tests (`test_02_activity_generation.py`)**: Validates screen-free activity generation across domains (Cognitive, Language, Motor) and checks boundary conditions (invalid age, missing domain).
- **AI Story Tests (`test_03_story_generation.py`)**: Tests personalized story generation, fallback name handling, validation, and performance.
- **Negative & Edge Cases (`test_04_negative.py`)**: Asserts HTTP 405 on invalid HTTP methods, HTTP 422 on empty/malformed inputs, HTTP 404 on undefined routes, and safe mitigation of SQL injection attacks.
- **Web UI Tests (`test_05_ui_web.py`)**: Headless Chrome tests checking page loads, login form fields, and client-side form validation. Gracefully skips when `UI_URL` is not provided.
- **HTML Reporting**: Self-contained HTML test reports powered by `pytest-html`.

---

## 🛠️ Installation

1. Navigate to the `selenium_tests` directory:
   ```bash
   cd C:\Codes\flutter-app\selenium_tests
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

---

## 🚀 Running the Tests

### 1. Run All Tests with HTML Report
```bash
python -m pytest -v --html=report.html --self-contained-html
```
Or from the project root (`C:\Codes\flutter-app`):
```bash
python -m pytest selenium_tests/ -v --html=selenium_tests/report.html --self-contained-html
```

### 2. Run API Tests Only
```bash
python -m pytest selenium_tests/ -m api -v
```

### 3. Run UI Tests Only (with Target URL)
```cmd
set UI_URL=https://littlelumin-web.onrender.com
python -m pytest selenium_tests/ -m ui -v
```
*(In PowerShell: `$env:UI_URL="https://littlelumin-web.onrender.com"; python -m pytest selenium_tests/ -m ui -v`)*

### 4. Custom API Base URL
To target local backend or a custom staging environment:
```cmd
set API_BASE_URL=http://localhost:8000
python -m pytest selenium_tests/ -m api -v
```

### 5. Run via Batch Script
Double click or run `run_tests.bat` located in either `C:\Codes\flutter-app\` or `C:\Codes\flutter-app\selenium_tests\`:
```cmd
run_tests.bat
```

---

## Note on Render Free Tier

The backend runs on Render's free tier, which sleeps after ~15 minutes of inactivity.
The test suite includes a warmup fixture that pings `/health` before running any test.
This adds 30-60 seconds to the first test run but prevents false timeouts.

If tests still fail due to cold start, run them twice — the second run will be fast and clean.

---

## 📁 Directory Structure

```
selenium_tests/
│── conftest.py                   # Pytest fixtures (base_url, http_session, driver)
│── pytest.ini                    # Pytest markers and default settings
│── requirements.txt              # Test dependency versions
│── README.md                     # Documentation and run instructions
│── run_tests.bat                 # One-click Windows runner batch script
│── test_01_health.py             # Root and health endpoint tests (5 tests)
│── test_02_activity_generation.py# AI activity generation tests (6 tests)
│── test_03_story_generation.py   # AI story generation tests (4 tests)
│── test_04_negative.py           # Negative and edge-case API tests (6 tests)
└── test_05_ui_web.py             # Headless Chrome UI tests (5 tests)
```
