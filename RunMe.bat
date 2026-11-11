@echo off
setlocal
REM ============================================================
REM  Update-SecureBootCert v2.1 - one-click launcher
REM  Asks for administrator rights, then runs Update-SecureBootCert.ps1.
REM  Any arguments are passed on to the script, for example:
REM    RunMe.bat -CheckOnly
REM    RunMe.bat -Lang zh-TW   (Traditional Chinese interface)
REM ============================================================

REM fltmc works only as administrator (and, unlike "net session",
REM does not depend on the Server service).
fltmc >nul 2>&1
if errorlevel 1 goto :elevate
goto :run

:elevate
echo Requesting administrator rights...
set "SB_SELF=%~f0"
set "SB_ARGS=%*"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$a = @{ FilePath = $env:SB_SELF; Verb = 'RunAs' }; if ($env:SB_ARGS) { $a.ArgumentList = $env:SB_ARGS }; try { Start-Process @a -ErrorAction Stop } catch { Write-Host 'Administrator rights were not granted.' -ForegroundColor Yellow; exit 1 }"
if errorlevel 1 pause
exit /b

:run
set "SB_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "SB_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%SB_PS%" set "SB_PS=powershell.exe"

"%SB_PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-SecureBootCert.ps1" -NoPause %*
set "SB_RC=%errorlevel%"

echo.
echo ================================================================
if "%SB_RC%"=="0"    echo   Finished: nothing to do, or the update is complete.
if "%SB_RC%"=="2"    echo   The update is not finished. Read the messages above.
if "%SB_RC%"=="3"    echo   Cancelled. Nothing was changed.
if "%SB_RC%"=="3010" echo   Restart the PC, then run RunMe.bat again to finish.
if "%SB_RC%"=="1"    echo   FAILED. Read the messages above.
echo   Log files: %ProgramData%\Update-SecureBootCert
echo ================================================================
echo.
pause
exit /b %SB_RC%
