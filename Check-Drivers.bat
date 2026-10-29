@echo off
REM PC-Driver-Check - double-click to run. Asks for administrator rights.
REM Optional: Check-Drivers.bat -ScanOnly   /   Check-Drivers.bat -IncludeDevices
cd /d "%~dp0"
net session >nul 2>&1
if errorlevel 1 (
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
    ) else (
        powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath '%~f0' -ArgumentList '%*'"
    )
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Driver-Check.ps1" %*
pause
