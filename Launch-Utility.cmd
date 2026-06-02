@echo off
fltmc >nul 2>&1
if "%errorLevel%" NEQ "0" (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "MECM-to-Intune-App-Migrator.ps1"
