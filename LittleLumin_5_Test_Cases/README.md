# LittleLumin — Five Test Cases

This folder contains only the five requested test cases:
1. Root endpoint availability
2. Login form presence (web frontend only)
3. Personalized story generation
4. Empty email validation (web frontend only)
5. Activity generation response time

## 1. Install dependencies
Open PowerShell in this folder and run:

```powershell
py -m pip install -r requirements.txt
```

Google Chrome must be installed for Selenium browser tests. Selenium Manager normally handles the ChromeDriver setup automatically.

## 2. Configure backend URL
The default backend is `https://littlelumin.onrender.com`. To override it:

```powershell
$env:API_BASE_URL="https://littlelumin.onrender.com"
```

## 3. Configure web frontend URL
Only needed for Cases 2 and 4. Replace the placeholder with the actual web frontend URL:

```powershell
$env:UI_URL="https://YOUR-ACTUAL-WEB-FRONTEND-URL"
```

If LittleLumin only has a native Flutter mobile UI, Cases 2 and 4 need Flutter/widget or device testing instead of Selenium.

## 4. Run individual cases
```powershell
py -m pytest test_case_1_root_endpoint.py -s
py -m pytest test_case_2_login_form.py -s
py -m pytest test_case_3_personalized_story.py -s
py -m pytest test_case_4_empty_email.py -s
py -m pytest test_case_5_activity_response_time.py -s
```

## 5. Run all five and create an HTML report
```powershell
py -m pytest -s --html=report.html --self-contained-html
```

Cases 2 and 4 will be skipped if `UI_URL` is not configured. The suite does not include a pre-generated report because an old report would show stale results. Only mark tests PASS/FAIL based on the actual run. AI generation tests require HTTP 200 and a valid generated payload to pass; an HTTP 500 is not considered successful generation.
