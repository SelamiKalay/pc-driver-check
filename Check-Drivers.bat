@echo off
REM PC-Driver-Check - double-click to run. Asks for administrator rights.
REM Optional: Check-Drivers.bat -ScanOnly   /   Check-Drivers.bat -IncludeDevices
cd /d "%~dp0"
net session >nul 2>&1
if errorlevel 1 (
    REM Path and arguments go through environment variables, so quotes or ' in the
    REM folder name (e.g. C:\Users\O'Brien) cannot break the PowerShell command line
    set "PCDC_SELF=%~f0"
    set "PCDC_ARGS=%*"
    if "%~1"=="" (
        powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath $env:PCDC_SELF"
    ) else (
        powershell -NoProfile -Command "Start-Process -Verb RunAs -FilePath $env:PCDC_SELF -ArgumentList $env:PCDC_ARGS"
    )
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PC-Driver-Check.ps1" %*
set "PCDC_RC=%errorlevel%"
pause
exit /b %PCDC_RC%
