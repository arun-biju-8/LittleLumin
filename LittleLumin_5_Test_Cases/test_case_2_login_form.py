import os
import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options

UI_URL = os.getenv("UI_URL")

def test_case_2_login_form_presence():
    assert UI_URL, "Set UI_URL before running this test."

    options = Options()
    options.add_argument("--window-size=1366,1000")

    driver = webdriver.Chrome(options=options)

    try:
        print("\nTEST CASE 2: LOGIN FORM PRESENCE")
        print("URL:", UI_URL)

        driver.get(UI_URL)
        time.sleep(15)

        driver.save_screenshot("case2_login_page.png")

        print("Page title:", driver.title)
        print("Current URL:", driver.current_url)
        print("Page source preview:")
        print(driver.page_source[:1500])

        print("\nFlutter-related elements:")
        for selector in [
            "flt-glass-pane",
            "flt-semantics-host",
            "flt-text-editing-host",
            "input",
            "button"
        ]:
            elements = driver.find_elements(By.CSS_SELECTOR, selector)
            print(f"{selector}: {len(elements)}")

        print("\nScreenshot saved: case2_login_page.png")
        print("Inspect the screenshot and browser output.")

    finally:
        driver.quit()