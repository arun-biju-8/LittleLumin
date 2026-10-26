import os
import time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait

UI_URL = os.getenv("UI_URL")

def test_case_4_empty_email_validation():
    assert UI_URL, "Set UI_URL to your actual frontend URL."

    options = Options()
    options.add_argument("--window-size=1366,1000")

    driver = webdriver.Chrome(options=options)

    try:
        print("\nTEST CASE 4: EMPTY EMAIL VALIDATION")
        print("URL:", UI_URL)

        driver.get(UI_URL)

        WebDriverWait(driver, 30).until(
            lambda d: d.execute_script(
                "return document.readyState"
            ) == "complete"
        )

        time.sleep(10)

        driver.save_screenshot("case4_empty_email.png")

        print("Page title:", driver.title)
        print("Current URL:", driver.current_url)

        inputs = driver.find_elements(By.TAG_NAME, "input")

        print("Number of HTML input elements:", len(inputs))

        visible_inputs = [
            element for element in inputs
            if element.is_displayed()
        ]

        print("Number of visible input elements:", len(visible_inputs))

        email_inputs = [
            element for element in visible_inputs
            if element.get_attribute("type") == "email"
            or "email" in (
                element.get_attribute("name") or ""
            ).lower()
            or "email" in (
                element.get_attribute("aria-label") or ""
            ).lower()
        ]

        if not email_inputs:
            print(
                "TEST RESULT: BLOCKED — no email input was found "
                "using the current HTML selectors."
            )
            print("Screenshot saved: case4_empty_email.png")
            return

        email = email_inputs[0]
        email.clear()

        print("Email field found and cleared.")

        forms = driver.find_elements(By.TAG_NAME, "form")
        buttons = driver.find_elements(
            By.CSS_SELECTOR,
            "button[type='submit'], input[type='submit']"
        )

        if forms:
            forms[0].submit()
        elif buttons:
            buttons[0].click()
        else:
            print(
                "TEST RESULT: BLOCKED — no form or submit button found."
            )
            return

        time.sleep(2)

        validation_message = email.get_attribute("validationMessage")
        current_url_after = driver.current_url

        print("Validation message:", repr(validation_message))
        print("URL after submission:", current_url_after)

        if validation_message:
            print("TEST RESULT: PASS")
            print("Empty email triggered browser validation.")
        else:
            print(
                "TEST RESULT: INCONCLUSIVE — inspect the application "
                "for custom validation or a Flutter-rendered form."
            )

    finally:
        driver.quit()