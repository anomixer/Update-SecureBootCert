@echo off
REM ============================================================
REM SecureBootCertFix - One-Click Launcher (Auto Admin)
REM ============================================================
REM This batch file automatically requests administrator rights
REM and runs the PowerShell script.
REM ============================================================

REM Check for admin rights
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :RunScript
) else (
    goto :RequestAdmin
)

:RequestAdmin
echo Requesting administrator privileges...
powershell -Command "Start-Process '%~f0' -Verb RunAs"
exit /b

:RunScript
echo.
echo ================================================================
echo   SecureBootCertFix - Windows Secure Boot Certificate Updater
echo ================================================================
echo.
echo Running with administrator privileges...
echo.

REM Run PowerShell script with bypass execution policy
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Update-SecureBootCert.ps1"

if %errorlevel% equ 0 (
    echo.
    echo ================================================================
    echo   Update process finished.
    echo ================================================================
) else (
    echo.
    echo ================================================================
    echo   Update process ABORTED or FAILED.
    echo ================================================================
)
echo.
pause
