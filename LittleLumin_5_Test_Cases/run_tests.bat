@echo off
cd /d "%~dp0"
py -m pytest -s --html=report.html --self-contained-html
pause
