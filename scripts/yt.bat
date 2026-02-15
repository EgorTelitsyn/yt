@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0yt.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Error occurred. See above.
    pause
)
