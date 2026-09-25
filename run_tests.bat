@echo off
cd /d C:\Codes\flutter-app
python -m pytest selenium_tests/ -v --html=selenium_tests/report.html --self-contained-html
pause
